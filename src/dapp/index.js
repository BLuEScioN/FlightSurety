import DOM from "./dom";
import Contract from "./contract";
import "./flightsurety.css";
import moment from "moment-timezone";

(async () => {
  let contract = new Contract("localhost", () => {
    /********************************************************************************************/
    //                                     LOGGING
    /********************************************************************************************/

    DOM.elid("log-airlines").addEventListener("click", async () => {
      contract.logAirlines();
    });

    DOM.elid("log-authorized-airlines").addEventListener("click", async () => {
      contract.logAuthorizedAirlines();
    });

    DOM.elid("log-app-owner").addEventListener("click", async () => {
      contract.logAppOwner();
    });

    DOM.elid("log-data-owner").addEventListener("click", async () => {
      contract.logDataOwner();
    });

    DOM.elid("log-flights").addEventListener("click", async () => {
      contract.logFlights();
    });

    DOM.elid("log-passengers").addEventListener("click", async () => {
      contract.logPassengers();
    });

    DOM.elid("log-app-balance").addEventListener("click", async () => {
      contract.logAppBalance();
    });

    DOM.elid("log-data-balance").addEventListener("click", async () => {
      contract.logDataBalance();
    });

    DOM.elid("log-votes").addEventListener("click", async () => {
      contract.logVotes();
    });

    DOM.elid("log-doesSenderMeetAuthorizationRequirements").addEventListener(
      "click",
      async () => {
        contract.logDoesSenderMeetAuthorizationRequirements();
      }
    );

    DOM.elid("log-passenger-flight-insurance").addEventListener(
      "click",
      async () => {
        contract.logPassengerFlightInsurance();
      }
    );

    /********************************************************************************************/
    //                                     AIRLINE ACTIONS
    /********************************************************************************************/

    // REGISTER AIRLINE
    DOM.elid("register-airline").addEventListener("click", async () => {
      let address = DOM.elid("airline-address").value;
      let name = DOM.elid("airline-name").value;
      contract.registerAirline(address, name);
    });

    // FUND
    DOM.elid("fund").addEventListener("click", async () => {
      let funds = DOM.elid("funds").value;
      contract.fund(funds);
    });

    // VOTE
    DOM.elid("vote").addEventListener("click", async () => {
      let airlineAddress = DOM.elid("vote-airline-address").value;
      contract.vote(airlineAddress);
    });

    /********************************************************************************************/
    //                                     FLIGHT ACTIONS
    /********************************************************************************************/

    // REGISTER FLIGHT
    DOM.elid("register-flight-1").addEventListener("click", async () => {
      const airlineName = "first";
      const flightId = 1;
      const departure = "seattle";
      const arrival = "cincinnati";
      const flightName = `${departure} to ${arrival}`;
      const date = new Date(2021, 8, 1, 23);
      const departureTime = moment.tz(date, "America/Los_Angeles").unix();
      const price = 350;
      contract.registerFlight(
        airlineName,
        flightId.toString(),
        departureTime,
        price
      );
    });

    DOM.elid("register-flight-2").addEventListener("click", async () => {
      const airlineName = "first";
      const flightId = 2;
      const departure = "seattle";
      const arrival = "nyc";
      const flightName = `${departure} to ${arrival}`;
      const date = new Date(2021, 8, 1, 7, 50);
      const departureTime = moment.tz(date, "America/Los_Angeles").unix();
      const price = 450;
      contract.registerFlight(
        airlineName,
        flightId.toString(),
        departureTime,
        price
      );
    });

    DOM.elid("register-flight-3").addEventListener("click", async () => {
      const airlineName = "first";
      const flightId = 3;
      const departure = "seattle";
      const arrival = "milan";
      const flightName = `${departure} to ${arrival}`;
      const date = new Date(2021, 8, 1, 23, 45);
      const departureTime = moment.tz(date, "America/Los_Angeles").unix();
      const price = 685;
      contract.registerFlight(
        airlineName,
        flightId.toString(),
        departureTime,
        price
      );
    });

    DOM.elid("register-flight-4").addEventListener("click", async () => {
      const airlineName = "first";
      const flightId = 4;
      const departure = "cincinnati";
      const arrival = "seattle";
      const flightName = `${departure} to ${arrival}`;
      const date = new Date(2021, 8, 1, 12);
      const departureTime = moment.tz(date, "America/New_York").unix();
      const price = 250;
      contract.registerFlight(
        airlineName,
        flightId.toString(),
        departureTime,
        price
      );
    });

    /********************************************************************************************/
    //                                     PASSENGER ACTIONS
    /********************************************************************************************/

    // PASSENGER BUY INSURANCE
    DOM.elid("buy-flight-insurance").addEventListener("click", () => {
      let flightId = DOM.elid("insurance-flight-id").value;
      let payment = DOM.elid("insurance-payment").value;
      contract.buyFlightInsurance(flightId, payment);
    });

    // PASSENGER WITHDRAWS FLIGHT INSURANCE PAYOUT
    DOM.elid("claim-credit").addEventListener("click", () => {
      contract.withdrawFlightInsurancePayout();
    });

    /********************************************************************************************/
    //                                     ORACLE ACTIONS
    /********************************************************************************************/

    // FETCH FLIGHT STATUS
    DOM.elid("fetch-flight-status").addEventListener("click", async () => {
      const flightId = DOM.elid("fetch-flight-status-flight-id").value;
      contract.fetchFlightStatus(flightId);
    });
  });
})();
