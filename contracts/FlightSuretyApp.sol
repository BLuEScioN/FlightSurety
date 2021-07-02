pragma solidity ^0.8.6;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/
    FlightSuretyData flightSuretyData;
    address private contractOwner;          // Account used to deploy contract

    // struct Flight {
    //     bool isRegistered;
    //     uint8 statusCode;
    //     uint256 updatedTimestamp;        
    //     address airline;
    // }

 
    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in 
    *      the event there is an issue that needs to be fixed
    */
    modifier requireIsOperational() 
    {
         // Modify to call data contract's status
        require(flightSuretyData.isOperational(), "Contract is currently not operational");  
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAirlineAnte() {
        require(flightSuretyData.isAirlineInsured(msg.sender), "Airline account" + msg.sender + "has not put up the required ante/insurance.");
        _;
    }

    // modifier checkValue
    //     (
    //         uint price, 
    //         address addressToFund
    //     )
    // {
    //     uint amountToReturn = msg.value - price;
    //     addressToFund.transfer(amountToReturn);
    //     _;
    // }

    modifier requireValidAddress
        (
            address addressToCheck
        ) 
    {
        require(addressToCheck != address(0), "Address must be a valid.");
        _;
    }

    modifier requireAirlineExists
        (
            address airline
        )
    {
        require(flightSuretyData.methods.airlineExists().call)
    }
    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor (
        address dataContract
    ) public 
    {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
        // registerAirline(contractOwner, "Contract Owner");

        // emit RegisterAirline(contractOwner);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational() 
        public 
        pure 
        returns(bool) 
    {
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    // function setDataContract
    //     (
    //         address dataContract
    //     )
    //     external
    //     requireContractOwner
    // {
    //     flightSuretyData = FlightSuretyData(dataContract);
    // }

    function now(){
        return block.timestamp;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /********************************************************************************************/
    //                                     AIRLINE FUNCTIONS                             
    /********************************************************************************************/

   /**
    * @dev Add an airline to the registration queue
    *      Can only be called from FlightSuretyApp contract
    *
    */   
    function registerAirline
        (
            address airline,
            string name
        )
        external
        pure
        requireIsOperational
        requireValidAddress(airline)
        requireAuthorizedAirline
        returns (bool)
    {
        require(!airlines[airline].isRegistered, "Airline is already registered");

        if (numAirlines < MULTIPARTY_MIN_AIRLINES) {
            airlines[airline] = Airline({
                account: airline,
                name: name,
                isRegistered: true,
                insuranceMoney: 0,
                votes: 0, 
                exists: true
            });
        } else {
            airlines[airline] = Airline({
                account: airline,
                isRegistered: false,
                name: name,
                insuranceMoney: 0,
                votes: 0, 
                exists: true
            });
        }
        vote(airline);
        numAirlines++;
        return true;
    }

    function vote
        (
            address airline
        )
        public
        requireIsOperational
        requireAuthorizedAirline
        requireVote(airline)
    {
        require(airlines[airline].exists == true, "Airline has not been registered before.");
        require(airlines[airline].isRegistered == false, "Cannot vote for an airline that has already been registered.");

        airlines[airline].votes = airlines[airline].votes.add(1);
        if (airlines[airline].votes > MULTIPARTY_MIN_AIRLINES.div(2)) airlines[airline].isRegistered = true; // make a function call?
    }

    /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund()
        public
        payable
        requireIsOperational
    {
        require(msg.value > 0, "Fund contributions must be greater than 0."); // make modifier
        require(airlines[msg.sender].exists == true, "The airline must exist."); // requireAirlineExists

        uint256 memory currentInsurancePool = airlines[msg.sender].insuranceMoney;
        airlines[msg.sender].insurancePool = currentInsurancePool.add(msg.value);
    }


    /********************************************************************************************/
    //                                     FLIGHT FUNCTIONS                             
    /********************************************************************************************/
   /**
    * @dev Register a future flight for insuring.
    *
    */  
    function registerFlight
        (   
            string flight, 
            uint256 timestamp,
            uint256 price
        )
        external
        requireIsOperational
        requireAirlineAnte
    {
        require(timestamp > now(), "Departure time has to be in the future.");

        bytes32 key = getFlight(msg.sender, flight, timestamp);
        require(!flights[key].exists, "Flight already registered.");

        flights[key] = Flight({
            airline: airline,
            flight: flight,
            departureTime: departureTime,
            status: STATUS_CODE_ON_TIME,
            price: price,
            exists: true
        });
    }

    /********************************************************************************************/
    //                                     PASSSENGER FUNCTIONS                             
    /********************************************************************************************/

    /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyFlightInsurance
        (
            string flight
        )
        external
        payable
        requireIsOperational
        returns (uint256, address, uint256)
    {
        require(msg.sender == tx.origin, "Contracts not allowed.");
        require(msg.value > 0, "Flight insurance isn't free.");

        uint256 memory insurancePurchased = msg.value;
        uint256 memory refund = 0;
        if (msg.value > INSURANCE_PRICE_LIMIT) {
            insurancePurchased = INSURANCE_PRICE_LIMIT;
            refund = msg.value.sub(INSURANCE_PRICE_LIMIT);
            msg.sender.transfer(refund); // make modifier
        }

        if (!passengers[msg.sender].exists) {
            passengers[msg.sender] = Passenger({
                account: msg.sender,
                payout: 0, 
                exists: true
            });
            passengerAccounts.push(msg.sender);
        } 

        passengers[msg.sender].flightsPurchased[flight] = insurancePurchased; // record insurance paid for flight
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
        (
            string flight
        )
        external
        pure
        requireIsOperational
    {
        for (uint256 i = 0; i < passengerAccounts.length; i++) {
            if (passengers[passengerAccounts[i]].flightsPurchased[flight] != 0) {
                uint256 memory currentPayout = passengers[passengerAccounts[i]].payout;
                uint256 memory flightInsurancePurchased = passengers[passengerAccounts[i]].flightsPurchased[flight];
                delete passengers[passengerAccounts[i]].flightsPurchased[flight];
                passengers[passengerAccounts[i]].payout = currentPayout.add((flightInsurancePurchased.mul((flightInsurancePurchased.div(2)))));
            }
        }
    }

     /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function pay
        (
            address passenger
        )
        external
        pure
        requireIsOperational
        requireContractOwner
    {
        require(passenger == tx.origin, "Contracts are not allowed to call this function."); // make modifier
        require(passengers[passenger].payout > 0, "There is no payout available for the account."); // make modifier

        uint256 memory payout = passengers[passenger].payout;
        uint256 memory currentBalance = address(this).balance;

        require(currentBalance > payout, "The contract does not have enough ether to pay the passenger.");

        passengers[passenger].payout = 0;
        passenger.transfer(payout);
    }

    /********************************************************************************************/
    //                                    ORACLE FUNCTIONS                             
    /********************************************************************************************/

     // Generate a request for oracles to fetch flight information
    function fetchFlightStatus
        (
            address airline,
            string flight,
            uint256 timestamp                            
        )
        external
    {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        oracleResponses[key] = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        emit OracleRequest(index, airline, flight, timestamp);
    } 

    
   /**
    * @dev Called after oracle has updated flight status
    *
    */  
    function processFlightStatus
        (
            address airline,
            string memory flight,
            uint256 timestamp,
            uint8 statusCode
        )
        internal
        pure
        requireIsOperational
    {
        bytes32 key = keccak256(abi.encodePacked(flight, airline));
        require(flights[key].isRegistered, "Flight is not registered.");

        flights[key].updatedTimestamp = timestamp;
        flights[key].statusCode = statusCode;

        if (statusCode == STATUS_CODE_LATE_AIRLINE) flightSuretyData.creditInsurees(flght);
    }


   

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;    

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;        
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);


    // Register an oracle with the contract
    function registerOracle() 
        external
        payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
            isRegistered: true,
            indexes: indexes
        });
    }

    function getMyIndexes ()
        view
        external
        returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse 
    (
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp,
        uint8 statusCode
    )
        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");

        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp)); 
        require(oracleResponses[key].isOpen, "Oracle request is not open");

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
        (
            address airline,
            string flight,
            uint256 timestamp
        )
        pure
        internal
        returns(bytes32) 
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes
        (                       
            address account         
        )
        internal
        returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);
        
        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex
        (
            address account
        )
        internal
        returns (uint8)
    {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }
}   
