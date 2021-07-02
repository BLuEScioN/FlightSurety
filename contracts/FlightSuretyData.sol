pragma solidity ^0.8.6;

import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";

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
      bool exists;
      uint256 status;
    //   bool registered;
      uint256 departuretime;
      uint256 price;
    //   mapping(address => bool) didByInsurance;
    }

    mapping(bytes32 => Flight) private flights;

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
            votes: 0
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
        require(authorizedAirlines[msg.sender] == true, "Caller is not an authorized airline.");
        _;
    }

    modifier requireVote
        (
            address airline
        ) 
    {
        require(airlineVotes[msg.sender][airline] == 0, "The registered airline/msg.sender has already voted to authorize the airline" + airline + ".");
        _;
    }


    // modifier requireInsuredAirline() {
    //     require(address(this).balance > 10 ether, "Airline has insufficient insurance");
    //     _;
    // }

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
        external
        requireIsOperational
        requireAuthorizedAirline 
    {
        authorizedAirlines[airline] == true;
    }

    /**
    * @dev Strips an airline of authority to perform specific actions
    */    
    function deauthorizeAirline
        (
            address airline
        )
        external
        requireIsOperational
        requireAuthorizedAirline 
    {
        delete authorizedAirlines[airline];
    }

    function isAirlineInsured
        (
            address airline
        ) 
        external
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

    function airlineExists
        (
            address airline
        )
        public
        requireIsOperational
        returns (bool)
    {
        if (airlines[airline].exists == 1) return true;
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
        if (airlines[airline].isRegistered == 1) return true;
        else return false;
    }


    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

//    /**
//     * @dev Add an airline to the registration queue
//     *      Can only be called from FlightSuretyApp contract
//     *
//     */   
//     function registerAirline
//         (
//             address airline,
//             string name
//         )
//         external
//         pure
//         requireIsOperational
//         requireAuthorizedAirline
//         returns (bool)
//     {
//         require(airline != address(0), "airline must be a valid address.");
//         require(!airlines[airline].isRegistered, "Airline is already registered");

//         if (numAirlines < MULTIPARTY_MIN_AIRLINES) {
//             airlines[airline] = Airline({
//                 account: airline,
//                 name: name,
//                 isRegistered: true,
//                 insuranceMoney: 0,
//                 votes: 0, 
//                 exists: true
//             });
//         } else {
//             airlines[airline] = Airline({
//                 account: airline,
//                 isRegistered: false,
//                 name: name,
//                 insuranceMoney: 0,
//                 votes: 0, 
//                 exists: true
//             });
//         }
//         vote(airline);
//         numAirlines++;
//         return true;
//     }

   
    

    // /**
    // * @dev Buy insurance for a flight
    // *
    // */   
    // function buy
    //     (
    //         string flightNum
    //     )
    //     external
    //     payable
    //     requireIsOperational
    //     returns (uint256, address, uint256)
    // {
    //     require(msg.sender == tx.origin, "Contracts not allowed.");
    //     require(msg.value > 0, "Flight insurance isn't free.");

    //     if (!passengers[msg.sender].exists) {
    //         passengers[msg.sender] = Passenger({
    //             account: msg.sender,
    //             payout: 0, 
    //             exists: true
    //         });
    //         passengers[msg.sender].flightsPurchased[flightNum] = msg.value;
    //         passengerAccounts.push(msg.sender);
    //     } else {
    //         passengers[msg.sender].flightsPurchased[flightNum] = msg.value;
    //     }

    //     if (msg.value > INSURANCE_PRICE_LIMIT) msg.sender.transfer(msg.value.sub(INSURANCE_PRICE_LIMIT));
    // }

    // /**
    //  *  @dev Credits payouts to insurees
    // */
    // function creditInsurees
    //     (
    //         string flight
    //     )
    //     external
    //     pure
    //     requireIsOperational
    // {
    //     for (uint256 i = 0; i < passengerAccounts.length; i++) {
    //         if (passengers[passengerAccounts[i]].flightsPurchased[flight] != 0) {
    //             uint256 currentPayout = passengers[passengerAccounts[i]].payout;
    //             uint256 flightPrice = passengers[passengerAccounts[i]].flightsPurchased[flight];
    //             delete passengers[passengerAccounts[i]].flightsPurchased[flight];
    //             passengers[passengerAccounts[i]].payout = currentPayout.add((flightPrice.mul((flightPrice.div(2)))));
    //         }
    //     }
    // }
    

    // /**
    //  *  @dev Transfers eligible payout funds to insuree
    //  *
    // */
    // function pay
    //     (
    //         address passenger
    //     )
    //     external
    //     pure
    //     requireIsOperational
    // {
    //     require(passenger == tx.origin, "Contracts are not allowed to call this function.");
    //     require(passengers[passenger].payout > 0, "There is no payout available for the account.");
    //     uint256 payout = passengers[passenger].payout;
    //     uint256 currentBalance = address(this).balance;
    //     require(currentBalance > payout, "The contract does not have enough ether to payout.");
    //     passengers[passenger].payout = 0;
    //     passenger.transfer(payout);
    // }

//    /**
//     * @dev Initial funding for the insurance. Unless there are too many delayed flights
//     *      resulting in insurance payouts, the contract should be self-sustaining
//     *
//     */   
//     function fund()
//         public
//         payable
//         requireIsOperational
//     {
//         require(msg.value > 0, "Fund contributions must be greater than 0.");
//         uint256 currentInsurancePool = airlines[msg.sender].insurancePool;
//         airlines[msg.sender].insurancePool = currentInsurancePool.add(msg.value);
//     }

    // function getFlightKey
    //     (
    //         address airline,
    //         string memory flight,
    //         uint256 timestamp
    //     )
    //     pure
    //     internal
    //     returns(bytes32) 
    // {
    //     return keccak256(abi.encodePacked(airline, flight, timestamp));
    // }

    // function registerFlight
    //     (
    //         bytes32 key, 
    //         address airline,
    //         string flight,
    //         uint256 departureTime,
    //         uint256 price, 
    //     ) 
    //     external
    //     requireIsOperational()
    //     isAuthorized()
    // {
    //     flights[key] = Flight({
    //         airline: airline,
    //         flight: flight,
    //         departureTime: departureTime
    //         status: STATUS_CODE_ON_TIME,
    //         price: price,
    //         exists: true
    //     });
    //   }

    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    // function () 
    //     external 
    //     payable 
    // {
    //     fund();
    // }
}

