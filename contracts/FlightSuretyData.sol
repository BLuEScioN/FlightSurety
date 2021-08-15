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

    // AIRLINES
    mapping(address => Airline) public airlines;
    uint256 public numAirlines = 0;
    address[] public airlineAddresses;

    mapping(address => bool) private authorizedAirlines;
    uint256 public numAuthorizedAirlines = 0;
    address[] public authorizedAirlinesArray;

    mapping(address => mapping(address => bool)) public airlineVotes; // registered airline to unregistered airline to yes or not vote

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
        string memory name = "First Airline";

        airlines[contractOwner] = Airline({
            account: contractOwner,
            name: name,
            isRegistered: true,
            insuranceMoney: 0,
            votes: 0,
            exists: true
        });
        emit AirlineRegistered(contractOwner, name, true);
        numAirlines = 1;
        airlineAddresses.push(contractOwner);

        // authorizeAirline(contractOwner); // cannot call because this has a modifier that requires the caller to be an authorized airline already
        authorizedAirlines[contractOwner] = true;
        authorizedAirlinesArray.push(contractOwner);
        numAuthorizedAirlines = 1;
        emit AirlineAuthorized(contractOwner, "");
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

    modifier requireAvailableCredit() {
        require(
            passengers[msg.sender].payout > 0,
            "The account has not credit available"
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

    function getVotes(address airline)
        public
        requireIsOperational
        returns (uint256)
    {
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
            account: airlineAddress,
            name: name,
            isRegistered: isRegistered,
            insuranceMoney: 0,
            votes: 0,
            exists: true
        });

        emit AirlineRegistered(airlineAddress, name, isRegistered);
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
        returns (
            // requireAuthorizedAirline
            uint256
        )
    {
        airlines[airlineAddress].votes = airlines[airlineAddress].votes.add(1);
        airlineVotes[votingAirlineAddress][airlineAddress] = true;
        emit AirlineVote(votingAirlineAddress, airlineAddress);

        if (doesAirlineHaveEnoughVotes(airlineAddress)) {
            airlines[airlineAddress].isRegistered = true;
            emit AirlineRegistered(
                airlineAddress,
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
