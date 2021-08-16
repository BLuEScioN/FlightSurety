pragma solidity >=0.5.0;

// import "../node_modules/openzeppelin-solidity/contracts/utils/math/SafeMath.sol";
import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address public contractOwner;
    bool private operational = true;
    mapping(address => bool) private authorizedCallers;

    // AIRLINES
    mapping(address => Airline) public airlines;
    uint256 public numAirlines = 0;
    address[] public airlineAddresses;
    uint256 airlineId = 1;

    mapping(address => bool) private authorizedAirlines;
    uint256 public numAuthorizedAirlines = 0;
    address[] public authorizedAirlinesArray;

    mapping(address => mapping(address => bool)) public airlineVotes; // registered airline to unregistered airline to yes or not vote

    struct Airline {
        address airlineAddress;
        uint256 id;
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
    mapping(address => mapping(string => uint256))
        public passengerFlightInsurance; // passenger address => flightId to insurance purchased
    mapping(address => string[]) public passengerFlightsPurchased;
    mapping(address => uint256) public numFlightsPurchased;
    struct Passenger {
        address passengerAddress;
        uint256 credit;
        bool exists;
    }

    // CONSTANTS
    uint256 public constant INSURANCE_PRICE_LIMIT = 1 ether;
    uint256 public constant MIN_ANTE = 10 ether;
    uint8 private constant MULTIPARTY_MIN_AIRLINES = 4;

    // FLIGHT STATUS CODES
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

    event AirlineRegistered(
        address airlineAddress,
        uint256 id,
        string name,
        bool isRegistered
    );
    event AirlineAuthorized(address airlineAddress, string name);
    event AirlineInRegistrationQueue(address airline, string name);
    event AirlineVote(address voter, address votee);

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() public {
        contractOwner = msg.sender;
        string memory name = "first";

        airlines[contractOwner] = Airline({
            airlineAddress: contractOwner,
            id: airlineId++,
            name: name,
            isRegistered: true,
            insuranceMoney: 0,
            votes: 0,
            exists: true
        });
        emit AirlineRegistered(
            contractOwner,
            airlines[contractOwner].id,
            name,
            true
        );
        numAirlines = 1;
        airlineAddresses.push(contractOwner);

        // authorizeAirline(contractOwner); // cannot call because this has a modifier that requires the caller to be an authorized airline already
        authorizedAirlines[contractOwner] = true;
        authorizedAirlinesArray.push(contractOwner);
        numAuthorizedAirlines = 1;
        emit AirlineAuthorized(contractOwner, "first");
    }

    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // ADMIN
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _;
    }

    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier isAuthorizedCaller() {
        require(
            authorizedCallers[msg.sender] == true,
            "Address is not authorized to make calls on data contract"
        );
        _;
    }

    // AIRLINE

    // Requires the airline to be registered and have an insurance fund of at least 10 ETH
    modifier requireAuthorizedAirline(address airlineAddress) {
        require(
            authorizedAirlines[airlineAddress] == true,
            "Caller is not an authorized airline."
        );
        _;
    }

    modifier requireVoterHasntVotedForAirline(
        address votingAirlineAddress,
        address airlineAddress
    ) {
        require(
            airlineVotes[votingAirlineAddress][airlineAddress] == false,
            "The msg.sender has already voted to authorize the airline."
        );
        _;
    }

    modifier requirePayment() {
        require(msg.value > 0, "This function requires an ether payment.");
        _;
    }

    modifier requirePassengerExists(address passenger) {
        require(
            passengers[passenger].exists == true,
            "The passenger does not exist."
        );
        _;
    }

    modifier requireAirlineExists(address airlineAddress) {
        require(
            airlines[airlineAddress].exists == true,
            "The airline does not exist."
        );
        _;
    }

    modifier requireAirlineDoesNotExist(address airlineAddress) {
        require(
            airlines[airlineAddress].exists == false,
            "The airline does not exist."
        );
        _;
    }

    modifier requireAirlineIsNotRegistered(address airlineAddress) {
        require(
            airlines[airlineAddress].isRegistered == false,
            "The airline is already registered."
        );
        _;
    }

    modifier requireAirlineInsurance() {
        require(
            isAirlineInsured(msg.sender),
            "Airline has not put up the required insurance."
        );
        _;
    }

    // FLIGHT

    modifier requireRegisteredFlight(string memory flight) {
        require(isFlightRegistered(flight), "Flight is not registered.");
        _;
    }

    modifier requireValidDepartureTime(uint256 departureTime) {
        require(departureTime > now, "Departure time cannot be in the past.");
        _;
    }

    modifier requireFlightIsNotAlreadyRegistered(string memory flightId) {
        require(!flights[flightId].exists, "Flight Id already registered.");
        _;
    }

    // PASSENGER

    modifier requireAvailableCredit(address passenger) {
        require(
            passengers[passenger].credit > 0,
            "The passenger does not have credit available"
        );
        _;
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    // ADMIN

    function isOperational() public view returns (bool) {
        return operational;
    }

    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    function authorizeCaller(address addressToAuthorize)
        external
        requireContractOwner()
    {
        authorizedCallers[addressToAuthorize] = true;
    }

    // AIRLINE

    /**
     * @dev Gives an airline authority to register flights
     */
    function authorizeAirline(address sender, address airlineAddress)
        internal
        requireIsOperational
    {
        authorizedAirlines[airlineAddress] = true;
        authorizedAirlinesArray.push(airlineAddress);
        numAuthorizedAirlines += 1;
    }

    /**
     * @dev Strips an airline of the authority to register flights
     */
    function deauthorizeAirline(address sender, address airlineAddress)
        internal
        requireIsOperational
    {
        delete authorizedAirlines[airlineAddress];
        for (uint256 i = 0; i < authorizedAirlinesArray.length; i++) {
            if (authorizedAirlinesArray[i] == airlineAddress) {
                delete authorizedAirlinesArray[i];
                numAuthorizedAirlines--;
            }
        }
    }

    function getVotes(address airlineAddress)
        public
        requireIsOperational
        returns (uint256)
    {
        return airlines[airlineAddress].votes;
    }

    function doesAirlineExist(address airlineAddress)
        public
        requireIsOperational
        returns (bool)
    {
        if (airlines[airlineAddress].exists == true) return true;
        else return false;
    }

    function doesAirlineMeetAuthorizationRequirements(address airlineAddress)
        internal
        requireIsOperational
        returns (bool)
    {
        if (
            isAirlineRegistered(airlineAddress) &&
            isAirlineInsured(airlineAddress)
        ) return true;
        else return false;
    }

    function doesSenderMeetAuthorizationRequirements()
        internal
        requireIsOperational
        returns (bool)
    {
        if (isAirlineRegistered(msg.sender) && isAirlineInsured(msg.sender))
            return true;
        else return false;
    }

    function isAirlineRegistered(address airlineAddress)
        public
        requireIsOperational
        returns (bool)
    {
        return airlines[airlineAddress].isRegistered;
    }

    function isAirlineInsured(address airlineAddress)
        public
        requireIsOperational
        returns (bool)
    {
        return airlines[airlineAddress].insuranceMoney > 10; // 1000000000000000000 18 0s
    }

    function doesAirlineHaveEnoughVotes(address airlineAddress)
        internal
        requireIsOperational
        returns (bool)
    {
        if (!isVotingRequiredForRegistration()) return true;
        else {
            uint256 voteThreshold = uint256(MULTIPARTY_MIN_AIRLINES).div(2);
            return airlines[airlineAddress].votes > voteThreshold;
        }
    }

    function isVotingRequiredForRegistration()
        internal
        requireIsOperational
        returns (bool)
    {
        return numAirlines >= MULTIPARTY_MIN_AIRLINES;
    }

    // FLIGHT

    function isFlightRegistered(string memory flight)
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
     */
    function registerAirline(
        address sender,
        address airlineAddress,
        string calldata name
    )
        external
        requireIsOperational
        requireAirlineDoesNotExist(airlineAddress)
        requireAuthorizedAirline(sender)
        returns (bool success, bool isRegistered)
    {
        bool isRegistered = doesAirlineHaveEnoughVotes(airlineAddress)
            ? true
            : false;
        airlines[airlineAddress] = Airline({
            airlineAddress: airlineAddress,
            id: airlineId++,
            name: name,
            isRegistered: isRegistered,
            insuranceMoney: 0,
            votes: 0,
            exists: true
        });

        emit AirlineRegistered(
            airlineAddress,
            airlines[airlineAddress].id,
            name,
            isRegistered
        );
        numAirlines++;
        airlineAddresses.push(airlineAddress);
        return (true, isRegistered);
    }

    function vote(address votingAirlineAddress, address airlineAddress)
        public
        requireIsOperational
        requireAirlineExists(airlineAddress)
        requireAirlineIsNotRegistered(airlineAddress)
        requireVoterHasntVotedForAirline(votingAirlineAddress, airlineAddress)
        requireAuthorizedAirline(votingAirlineAddress)
        returns (uint256)
    {
        airlines[airlineAddress].votes = airlines[airlineAddress].votes.add(1);
        airlineVotes[votingAirlineAddress][airlineAddress] = true;
        emit AirlineVote(votingAirlineAddress, airlineAddress);

        if (doesAirlineHaveEnoughVotes(airlineAddress)) {
            airlines[airlineAddress].isRegistered = true;
            emit AirlineRegistered(
                airlineAddress,
                airlines[airlineAddress].id,
                airlines[airlineAddress].name,
                true
            );
        }

        if (doesAirlineMeetAuthorizationRequirements(airlineAddress)) {
            authorizeAirline(votingAirlineAddress, airlineAddress);
            emit AirlineAuthorized(
                airlineAddress,
                airlines[airlineAddress].name
            );
        }

        return airlines[airlineAddress].votes;
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     */
    function fund(address airlineAddress)
        public
        payable
        requireIsOperational
        requireAirlineExists(airlineAddress)
        requirePayment
    {
        uint256 currentInsuranceMoney = airlines[airlineAddress].insuranceMoney;
        airlines[airlineAddress].insuranceMoney = currentInsuranceMoney.add(
            msg.value
        );

        if (doesAirlineMeetAuthorizationRequirements(airlineAddress)) {
            authorizeAirline(airlineAddress, airlineAddress);
            emit AirlineAuthorized(
                airlineAddress,
                airlines[airlineAddress].name
            );
        }
    }

    /********************************************************************************************/
    //                                     FLIGHT FUNCTIONS
    /********************************************************************************************/

    /**
     * @dev Register a future flight for insuring.
     */
    function registerFlight(
        address sender,
        string calldata airline,
        string calldata flight,
        uint256 departureTime,
        uint256 price
    )
        external
        requireIsOperational
        requireAuthorizedAirline(sender)
        requireValidDepartureTime(departureTime)
        requireFlightIsNotAlreadyRegistered(flight)
    {
        // bytes32 key = getFlight(msg.sender, flight, timestamp); // use key instead of Id

        // require(!flights[flight].exists, "Flight already registered.");

        // TODO: Validate that the sender is registering a flight for itself because it shouldnt
        // be registering a flight for another airline that is not authorized and insured
        // require(sender != airlines[airlineAddress], 'Registering a flight for another airline is prohibited');

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
        address payable passengerAddress
    )
        external
        payable
        requireIsOperational
    // returns (uint256, address, uint256)
    {
        uint256 insurancePurchased = msg.value;
        uint256 refund = 0;

        if (msg.value > INSURANCE_PRICE_LIMIT) {
            insurancePurchased = INSURANCE_PRICE_LIMIT;
            refund = msg.value.sub(INSURANCE_PRICE_LIMIT);
            passengerAddress.transfer(refund);
        }

        if (!passengers[passengerAddress].exists) {
            passengers[passengerAddress] = Passenger({
                passengerAddress: passengerAddress,
                credit: 0,
                exists: true
            });
            passengerAddresses.push(passengerAddress);
            numPassengers++;
        }

        passengerFlightsPurchased[passengerAddress].push(flightId); // record flightId of purchased flight
        numFlightsPurchased[passengerAddress]++;
        passengerFlightInsurance[passengerAddress][flightId] = insurancePurchased; // record flight insurance purchased
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditPassengers(string memory flightId)
        internal
        requireIsOperational
    {
        for (uint256 i = 0; i < passengerAddresses.length; i++) {
            address passengerAddress = passengerAddresses[i];


                uint256 flightInsurancePurchased
             = passengerFlightInsurance[passengerAddress][flightId];

            if (flightInsurancePurchased > 0) {
                uint256 currentCredit = passengers[passengerAddress].credit;

                passengerFlightInsurance[passengerAddress][flightId] = 0;

                passengers[passengerAddress].credit = currentCredit.add(
                    flightInsurancePurchased.mul(3).div(2)
                );
            }
        }

        // TODO: Check if any airlines have lost their authorized status because they had to payout from their insurance money and they have less than they are suppose to
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function withdraw(address payable passenger)
        external
        requireIsOperational
        requirePassengerExists(passenger)
        requireAvailableCredit(passenger)
    {
        uint256 credit = passengers[passenger].credit;
        uint256 currentBalance = address(this).balance;

        require(
            currentBalance >= credit,
            "The contract does not have enough ether to pay the passenger."
        );

        passengers[passenger].credit = 0;
        passenger.transfer(credit);
    }

    /********************************************************************************************/
    //                                     ORACLE FUNCTIONS
    /********************************************************************************************/

    function processFlightStatus(
        string calldata flightId,
        uint256 departureTime,
        uint8 statusCode
    ) external requireIsOperational requireRegisteredFlight(flightId) {
        // flights[flightId].departureTime = departureTime;
        flights[flightId].statusCode = statusCode;

        if (statusCode == STATUS_CODE_LATE_AIRLINE) creditPassengers(flightId);
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
