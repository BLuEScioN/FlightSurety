pragma solidity >=0.5.0;

// import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address public contractOwner; // Account used to deploy contract

    bool private operational = true; // Blocks all state changes throughout the contract if false

    // AIRLINES
    mapping(address => Airline) public airlines; // private
    uint256 public numAirlines = 0;
    address[] public airlineAddresses;

    mapping(address => bool) private authorizedAirlines; // isAuthorizedAirline
    uint256 public numAuthorizedAirlines = 0;
    address[] public authorizedAirlinesArray; // authorizedAirlineAddresses
    mapping(address => mapping(address => uint8)) public airlineVotes; // registered airline to unregistered airline to yes or not vote

    struct Airline {
        address account;
        string name;
        bool isRegistered;
        uint256 insuranceMoney;
        uint256 votes;
        bool exists;
    }

    // FLIGHTS
    mapping(string => Flight) public flights;
    uint256 public numFlights = 0;
    string[] public flightNameArray;
    struct Flight {
        string airline;
        string flight;
        uint256 departureTime;
        uint256 price;
        uint8 statusCode;
        bool isRegistered;
        bool exists;
    }

    // PASSENGERS
    mapping(address => Passenger) public passengers;
    address[] public passengerAddresses;
    uint256 public numPassengers = 0;
    struct Passenger {
        address account;
        mapping(string => uint256) flightsPurchased;
        uint256 payout;
        bool exists;
    }

    // CONSTANTS
    uint256 public constant INSURANCE_PRICE_LIMIT = 1 ether;
    uint256 public constant MIN_ANTE = 10 ether;
    uint8 private constant MULTIPARTY_MIN_AIRLINES = 4;
    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    /********************************************************************************************/
    /*                                     GETTERS AND SETTERS                                  */
    /********************************************************************************************/

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    event AirlineRegistered(address airline, string name);
    event AirlineInRegistrationQueue(address airline, string name);
    event AirlineVote(address voter, address votee);

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() public {
        contractOwner = msg.sender;
        string memory name = "First Airline";

        airlines[contractOwner] = Airline({
            account: contractOwner,
            name: name,
            isRegistered: true,
            insuranceMoney: 0,
            votes: 0,
            exists: true
        });
        emit AirlineRegistered(contractOwner, name);
        numAirlines = 1;
        airlineAddresses.push(contractOwner);

        // authorizeAirline(contractOwner); // cannot call because this has a modifier that requires the caller to be an authorized airline already
        // authorizedAirlines[address(this)] = true;
        authorizedAirlines[contractOwner] = true;
        authorizedAirlinesArray.push(contractOwner);
        numAuthorizedAirlines = 1;
        // if (address(this) != contractOwner) {
        //     authorizedAirlinesArray.push(address(this));
        //     numAuthorizedAirlines++;
        // }
        // authorizedAirlinesArray[numAuthorizedAirlines] = contractOwner; // delete
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
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireAuthorizedAirline() {
        require(
            authorizedAirlines[msg.sender] == true,
            "Caller is not an authorized airline."
        );
        _;
    }

    modifier requireVote(address airline) {
        require(
            airlineVotes[msg.sender][airline] == 0,
            "The registered airline/msg.sender has already voted to authorize the airline."
        );
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
        require(
            passengers[msg.sender].exists == true,
            "The passenger does not exist."
        );
        _;
    }

    modifier requireAvailableCredit() {
        require(
            passengers[msg.sender].payout > 0,
            "The account has not credit available"
        );
        _;
    }

    modifier requireRegisteredFlight(string memory flight) {
        require(isFlightRegistered(flight), "Flight is not registered.");
        _;
    }

    modifier requireAirlineInsurance() {
        require(
            isAirlineInsured(msg.sender),
            "Airline has not put up the required insurance."
        );
        _;
    }

    modifier requireValidDepartureTime(uint256 departureTime) {
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

    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled, all write transactions except for this one will fail
     */

    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    /**
     * @dev Gives an airline authority to perform specific actions
     */

    function authorizeAirline(address airline)
        public
        requireIsOperational
        requireAuthorizedAirline
    {
        authorizedAirlines[airline] = true;
        authorizedAirlinesArray.push(airline);
        // authorizedAirlinesArray[numAuthorizedAirlines] = airline; //delete
        numAuthorizedAirlines += 1;
    }

    /**
     * @dev Strips an airline of authority to perform specific actions
     */

    function deauthorizeAirline(address airline)
        public
        requireIsOperational
        requireAuthorizedAirline
    {
        delete authorizedAirlines[airline];
        for (uint256 i = 0; i < authorizedAirlinesArray.length; i++) {
            // delete
            if (authorizedAirlinesArray[i] == airline)
                delete authorizedAirlinesArray[i];
        }
    }

    function isAirlineInsured(address airline)
        public
        requireIsOperational
        returns (bool)
    {
        return airlines[airline].insuranceMoney > 10;
    }

    /** Returns the number of votes an airline has received */
    function getAirlineVotes(address airline) public returns (uint256) {
        return airlines[airline].votes;
    }

    function doesAirlineExist(address airline)
        public
        requireIsOperational
        returns (bool)
    {
        if (airlines[airline].exists == true) return true;
        else return false;
    }

    function isAirlineRegistered(address airline)
        public
        requireIsOperational
        returns (bool)
    {
        return airlines[airline].isRegistered;
    }

    function doesAirlineMeetAuthorizationRequirements(address airline)
        internal
        requireIsOperational
        returns (bool)
    {
        if (isAirlineRegistered(airline) && isAirlineInsured(airline))
            return true;
        else return false;
    }

    function isFlightRegistered(string memory flight)
        public
        requireIsOperational
        returns (bool)
    {
        return flights[flight].isRegistered;
    }

    function getVotes(address airline)
        public
        requireIsOperational
        returns (uint256)
    {
        return airlines[airline].votes;
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

    function registerAirline(address airline, string calldata name)
        external
        requireIsOperational
        returns (
            // requireAuthorizedAirline
            bool success,
            bool isRegistered,
            uint256 votes
        )
    {
        require(!doesAirlineExist(airline), "The airline already exists."); // turn into modifier
        // require(!isAirlineRegistered(airline), "Airline is already registered"); // superfluous

        isRegistered = false;
        if (numAirlines < MULTIPARTY_MIN_AIRLINES) {
            isRegistered = true;
            airlines[airline] = Airline({
                account: airline,
                name: name,
                isRegistered: isRegistered,
                insuranceMoney: 0,
                votes: 0,
                exists: true
            });
            emit AirlineRegistered(airline, name);
        } else {
            airlines[airline] = Airline({
                account: airline,
                isRegistered: isRegistered,
                name: name,
                insuranceMoney: 0,
                votes: 0,
                exists: true
            });
            emit AirlineInRegistrationQueue(airline, name);
        }
        if (!isAirlineRegistered(airline)) vote(airline);
        uint256 votes = getVotes(airline);
        numAirlines++;
        airlineAddresses.push(airline);
        return (true, isRegistered, votes);
    }

    function vote(address airline)
        public
        requireIsOperational
        // requireAuthorizedAirline
        requireVote(airline)
        returns (uint256)
    {
        require(doesAirlineExist(airline), "Airline does not exist.");
        require(
            !isAirlineRegistered(airline),
            "Cannot vote for an airline that has already been registered."
        );

        airlines[airline].votes = airlines[airline].votes.add(1);
        emit AirlineVote(msg.sender, airline);

        if (
            numAirlines >= MULTIPARTY_MIN_AIRLINES &&
            airlines[airline].votes > uint256(MULTIPARTY_MIN_AIRLINES).div(2)
        ) {
            airlines[airline].isRegistered = true;
            emit AirlineRegistered(airline, airlines[airline].name);
        }

        if (doesAirlineMeetAuthorizationRequirements(airline))
            authorizedAirlines[airline] == true;

        return airlines[airline].votes;
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */

    function fund(address airline, uint256 payment)
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

    function registerFlight(
        string calldata airline,
        string calldata flight,
        uint256 departureTime,
        uint256 price
    )
        external
        requireIsOperational
        // requireAuthorizedAirline
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

        flightNameArray.push(flight);
        numFlights++;
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

    function buyFlightInsurance(
        string calldata flightId,
        uint256 payment,
        address payable passengerAddress
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
            passengerAddress.transfer(refund);
        }

        if (!passengers[passengerAddress].exists) {
            passengers[passengerAddress] = Passenger({
                account: passengerAddress,
                payout: 0,
                exists: true
            });
            passengerAddresses.push(passengerAddress);
            numPassengers++;
        }

        passengers[passengerAddress]
            .flightsPurchased[flightId] = insurancePurchased; // record insurance paid for flight
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees(string memory flight) public requireIsOperational {
        for (uint256 i = 0; i < passengerAddresses.length; i++) {
            if (
                passengers[passengerAddresses[i]].flightsPurchased[flight] != 0
            ) {
                uint256 currentPayout = passengers[passengerAddresses[i]]
                    .payout;


                    uint256 flightInsurancePurchased
                 = passengers[passengerAddresses[i]].flightsPurchased[flight];
                delete passengers[passengerAddresses[i]]
                    .flightsPurchased[flight];
                passengers[passengerAddresses[i]].payout = currentPayout.add(
                    (
                        flightInsurancePurchased.mul(
                            (flightInsurancePurchased.div(2))
                        )
                    )
                );
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

        require(
            currentBalance > credit,
            "The contract does not have enough ether to pay the passenger."
        );

        passengers[msg.sender].payout = 0;
        msg.sender.transfer(credit);
    }

    /********************************************************************************************/
    //                                     ORACLE FUNCTIONS
    /********************************************************************************************/

    function processFlightStatus(
        string calldata flight,
        uint256 departureTime,
        uint8 statusCode
    ) external requireIsOperational requireRegisteredFlight(flight) {
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
    function() external payable {
        // fund();
    }
}
