pragma solidity >= 0.5.0;

// import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";


contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract

    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    
    mapping(address => Airline) private airlines;
    uint256 numAirlines = 0;

    mapping(address => uint8) private authorizedAirlines;
    mapping(address => mapping(address => uint8)) public airlineVotes; // registered airline to airline to yes or not vote

    mapping(address => Passenger) private passengers;
    address[] public passengerAccounts;

    uint256 public constant INSURANCE_PRICE_LIMIT = 1 ether;
    uint256 public constant MIN_ANTE = 10 ether;
    uint8 private constant MULTIPARTY_MIN_AIRLINES = 4;

    struct Airline {
        address account;
        string name;
        bool isRegistered;
        uint256 insuranceMoney;
        uint256 votes;
        bool exists;
    }

    struct Flight {
        string airline;
        string flight;
        uint256 departureTime;
        uint256 price;
        uint8 statusCode;
        bool isRegistered;
        bool exists;
    }
    mapping(string => Flight) private flights;

    // mapping(bytes32 => Flight) private flights;

    struct Passenger {
        address account;
        mapping(string => uint256) flightsPurchased;
        uint256 payout;
        bool exists;
    }

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;
    
    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address airline, string name);
    event AirlineInRegistrationQueue(address airline, string name);

    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    */
    constructor() 
        public 
    {
        contractOwner = msg.sender;

        airlines[contractOwner] = Airline({
            account: contractOwner,
            name: "Crypto Airlines",
            isRegistered: true,
            insuranceMoney: 0,
            votes: 0,
            exists: true
        });
        numAirlines = 1;
        authorizedAirlines[contractOwner] = 1;
    }

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
        require(operational, "Contract is currently not operational");
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

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireAuthorizedAirline()
    {
        require(authorizedAirlines[msg.sender] == 1, "Caller is not an authorized airline.");
        _;
    }

    modifier requireVote
        (
            address airline
        ) 
    {
        require(airlineVotes[msg.sender][airline] == 0, "The registered airline/msg.sender has already voted to authorize the airline.");
        _;
    }

   modifier requireEther() {
       require(msg.value > 0, "This function requires Ether.");
       _;
   }

   modifier requireEOA() {
        require(msg.sender == tx.origin, "Contracts not allowed.");
        _;
   }

   modifier requirePassengerExists() {
       require(passengers[msg.sender].exists == true, "The passenger does not exist.");
       _;
   }

   modifier requireAvailableCredit() {
        require(passengers[msg.sender].payout > 0, "The account has not credit available");
        _;
   }

   modifier requireRegisteredFlight
        (
            string memory flight
        )
    {
        require(isFlightRegistered(flight), "Flight is not registered.");
        _;
    }

    modifier requireAirlineInsurance() {
        require(isAirlineInsured(msg.sender), "Airline has not put up the required insurance.");
        _;
    }

    modifier requireValidDepartureTime
        (
            uint256 departureTime
        )
    {
        require(departureTime > now, "Departure time cannot be in the past.");
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    */      
    function isOperational() 
        public 
        view 
        returns(bool) 
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off
    *
    * When operational mode is disabled, all write transactions except for this one will fail
    */    
    function setOperatingStatus
        (
            bool mode
        ) 
        external
        requireContractOwner 
    {
        operational = mode;
    }

    /**
    * @dev Gives an airline authority to perform specific actions
    */    
    function authorizeAirline
        (
            address airline
        )
        public
        requireIsOperational
        requireAuthorizedAirline
    {
        authorizedAirlines[airline] == 1;
    }

    /**
    * @dev Strips an airline of authority to perform specific actions
    */    
    function deauthorizeAirline
        (
            address airline
        )
        public
        requireIsOperational
        requireAuthorizedAirline 
    {
        delete authorizedAirlines[airline];
    }

    function isAirlineInsured
        (
            address airline
        ) 
        public
        requireIsOperational
        returns (bool)
    {
        return airlines[airline].insuranceMoney > 10;
    }

    /** Returns the number of votes an airline has received */
    function getAirlineVotes
        (
            address airline
        ) 
        public
        returns (uint256)
    {
        return airlines[airline].votes;
    }

    function doesAirlineExist
        (
            address airline
        )
        public
        requireIsOperational
        returns (bool)
    {
        if (airlines[airline].exists == true) return true;
        else return false;
    }

    function isAirlineRegistered
        (
            address airline
        )
        public
        requireIsOperational
        returns (bool)
    {
        return airlines[airline].isRegistered;
    }

    function doesAirlineMeetAuthorizationRequirements
        (
            address airline
        )
        internal
        requireIsOperational
        returns (bool)
    {
        if (isAirlineRegistered(airline)  && isAirlineInsured(airline)) return true;
        else return false;
    }

    function isFlightRegistered
        (
            string memory flight
        )
        public 
        requireIsOperational
        returns (bool)
    {
        return flights[flight].isRegistered;
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
            string calldata name
        )
        external
        requireIsOperational
        requireAuthorizedAirline
        returns (bool, uint256)
    {
        require(!doesAirlineExist(airline), "The airline already exists.");
        require(!isAirlineRegistered(airline), "Airline is already registered");

        if (numAirlines < MULTIPARTY_MIN_AIRLINES) {
            airlines[airline] = Airline({
                account: airline,
                name: name,
                isRegistered: true,
                insuranceMoney: 0,
                votes: 0, 
                exists: true
            });
        emit AirlineRegistered(airline, name);
        } else {
            airlines[airline] = Airline({
                account: airline,
                isRegistered: false,
                name: name,
                insuranceMoney: 0,
                votes: 0, 
                exists: true
            });
            emit AirlineInRegistrationQueue(airline, name);
        }
        vote(airline);
        numAirlines++;
        return (true, getAirlineVotes(airline));
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
        require(doesAirlineExist(airline), "Airline does not exist.");
        require(!isAirlineRegistered(airline), "Cannot vote for an airline that has already been registered.");

        airlines[airline].votes = airlines[airline].votes.add(1);

        if (numAirlines >= MULTIPARTY_MIN_AIRLINES && airlines[airline].votes > uint256(MULTIPARTY_MIN_AIRLINES).div(2)) {
            airlines[airline].isRegistered = true; // make a function call?
            emit AirlineRegistered(airline, airlines[airline].name);
        }

        if (doesAirlineMeetAuthorizationRequirements(airline)) authorizedAirlines[airline] == 1;
    }

    /**
    * @dev Initial funding for the insurance. Unless there are too many delayed flights
    *      resulting in insurance payouts, the contract should be self-sustaining
    *
    */   
    function fund
        (
            address airline,
            uint256 payment
        )
        public
        payable
        requireIsOperational
        requireEther
    {
        require(airlines[airline].exists, "The airline does not exist.");

        uint256 currentInsuranceMoney = airlines[airline].insuranceMoney;
        airlines[airline].insuranceMoney = currentInsuranceMoney.add(payment);
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
            string calldata airline,
            string calldata flight, 
            uint256 departureTime,
            uint256 price
        )
        external
        requireIsOperational
        requireAuthorizedAirline
        requireValidDepartureTime(departureTime)
    {
        // bytes32 key = getFlight(msg.sender, flight, timestamp);
        require(!flights[flight].exists, "Flight already registered.");

        flights[flight] = Flight({
            airline: airline,
            flight: flight,
            departureTime: departureTime,
            price: price,
            statusCode: STATUS_CODE_ON_TIME,
            isRegistered: true,
            exists: true
        });
    }

    // function getFlightKey
    //     (
    //         address airline,
    //         string flight,
    //         uint256 timestamp
    //     )
    //     pure
    //     internal
    //     returns(bytes32) 
    // {
    //     return keccak256(abi.encodePacked(airline, flight, timestamp));
    // }

    /********************************************************************************************/
    //                                     PASSSENGER FUNCTIONS                             
    /********************************************************************************************/

    /**
    * @dev Buy insurance for a flight
    *
    */   
    function buyFlightInsurance
        (
            string calldata flight,
            uint256 payment,
            address payable passenger
        )
        external
        payable
        requireIsOperational
        // returns (uint256, address, uint256)
    {

        uint256 insurancePurchased = payment;
        uint256 refund = 0;

        if (payment > INSURANCE_PRICE_LIMIT) {
            insurancePurchased = INSURANCE_PRICE_LIMIT;
            refund = payment.sub(INSURANCE_PRICE_LIMIT);
            passenger.transfer(refund); 
        }

        if (!passengers[passenger].exists) {
            passengers[passenger] = Passenger({
                account: passenger,
                payout: 0, 
                exists: true
            });
            passengerAccounts.push(passenger);
        } 

        passengers[passenger].flightsPurchased[flight] = insurancePurchased; // record insurance paid for flight
    }

    /**
     *  @dev Credits payouts to insurees
    */
    function creditInsurees
        (
            string memory flight
        )
        public
        requireIsOperational
    {
        for (uint256 i = 0; i < passengerAccounts.length; i++) {
            if (passengers[passengerAccounts[i]].flightsPurchased[flight] != 0) {
                uint256 currentPayout = passengers[passengerAccounts[i]].payout;
                uint256 flightInsurancePurchased = passengers[passengerAccounts[i]].flightsPurchased[flight];
                delete passengers[passengerAccounts[i]].flightsPurchased[flight];
                passengers[passengerAccounts[i]].payout = currentPayout.add((flightInsurancePurchased.mul((flightInsurancePurchased.div(2)))));
            }
        }

        // Check if any airlines have lost their authorized status because they had to payout from their insurance money and they have less than they are suppose to
    }

     /**
     *  @dev Transfers eligible payout funds to insuree
     *
    */
    function withdraw()
        external
        requireIsOperational
        requireEOA
        requirePassengerExists
        requireAvailableCredit
    {
        uint256 credit = passengers[msg.sender].payout;
        uint256 currentBalance = address(this).balance;

        require(currentBalance > credit, "The contract does not have enough ether to pay the passenger.");

        passengers[msg.sender].payout = 0;
        msg.sender.transfer(credit);
    }

    /********************************************************************************************/
    //                                     ORACLE FUNCTIONS                             
    /********************************************************************************************/
    
    function processFlightStatus
        (
            string calldata flight,
            uint256 departureTime,
            uint8 statusCode
        )
        external
        requireIsOperational
        requireRegisteredFlight(flight)
    {
        flights[flight].departureTime = departureTime;
        flights[flight].statusCode = statusCode;

        if (statusCode == STATUS_CODE_LATE_AIRLINE) creditInsurees(flight);
    }

    // function updateFlightDepartureTime
    //     (
    //         string flight
    //         uint256 departureTime
    //     )
    // {
    //     flights[flight].departureTime = departureTime;
    // }

    // function updateFlightStatus
    //     (
    //         string flight
    //         uint8 status
    //     )
    // {
    //     flights[flight].status = status;
    // }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function () 
        external 
        payable 
    {
        // fund();
    }
}

