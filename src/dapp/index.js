import DOM from "./dom";
import Contract from "./contract";
import "./flightsurety.css";
import moment, { unix } from "moment-timezone";

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
      const airlineName = "first airline";
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
      const airlineName = "first airline";
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
      const airlineName = "first airline";
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
      const airlineName = "first airline";
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

    // PASSENGER CHECKS CREDIT
    DOM.elid("check-credit").addEventListener("click", () => {});

    // PASSENGER WITHDRAWS FLIGHT INSURANCE PAYOUT
    DOM.elid("claim-credit").addEventListener("click", () => {
      contract.withdrawFlightInsurancePayout();
    });

    /********************************************************************************************/
    //                                     ORACLE ACTIONS
    /********************************************************************************************/

    // CHECK STATUS
    // DOM.elid("statusButton").addEventListener("click", async (e) => {
    //   e.preventDefault();
    //   let buttonValue = e.srcElement.value;
    //   const response = await fetch(
    //     `http://localhost:3000/api/status/${buttonValue}`
    //   );
    //   const myJson = await response.json();
    //   console.log(myJson);
    //   display("", "Default flights status change submited to server.", [
    //     { label: "Server response: ", value: myJson.message },
    //   ]);
    // });

    // FETCH FLIGHT STATUS
    DOM.elid("fetch-flight-status").addEventListener("click", async () => {
      const flightId = DOM.elid("fetch-flight-status-flight-id").value;
      contract.fetchFlightStatus(flightId);
    });

    // ????
    // DOM.elid("flights-display").addEventListener("click", async (e) => {
    //   let flightCode = e.srcElement.innerHTML;
    //   console.log(e);
    //   console.log(flightCode);
    //   flightCode = flightCode
    //     .replace("✈ ", "")
    //     .replace("<b>", "")
    //     .replace("</b>", "");
    //   navigator.clipboard.writeText(flightCode).then(
    //     function() {
    //       console.log(
    //         `Async: Copying to clipboard was successful! Copied: ${flightCode}`
    //       );
    //     },
    //     function(err) {
    //       console.error("Async: Could not copy text: ", err);
    //     }
    //   );
    // });
  });
})();

let flightCount = 0;

function flightDisplay(flight, destination, airlineName, time) {
  var table = DOM.elid("flights-display");

  flightCount++;
  var row = table.insertRow(flightCount);
  row.id = flight;

  var cell1 = row.insertCell(0);
  var cell2 = row.insertCell(1);
  var cell3 = row.insertCell(2);
  var cell4 = row.insertCell(3);

  var date = new Date(+time);
  // Add some text to the new cells:
  cell1.innerHTML = "<b>✈ " + flight + "</b>";
  cell1.setAttribute("data-toggle", "tooltip");
  cell1.setAttribute("data-placement", "top");
  cell1.title = "Click on flight code to copy";
  cell2.innerHTML = destination.toUpperCase();
  cell3.innerHTML = date.getHours() + ":" + date.getMinutes();
  cell4.innerHTML = "ON TIME";
  cell4.style = "color:green";
  $('[data-toggle="tooltip"]')
    .tooltip()
    .mouseover();
  setTimeout(function() {
    $('[data-toggle="tooltip"]').tooltip("hide");
  }, 3000);
}

function addAirlineOption(airlineName, hash) {
  var dropdown = DOM.elid("airlineDropdownOptions");

  let newOption = DOM.button(
    { className: "dropdown-item", value: hash, type: "button" },
    airlineName
  );
  dropdown.appendChild(newOption);
}

function displaySpinner() {
  document.getElementById("oracles-spinner").hidden = false;
  document.getElementById("submit-oracle").disabled = true;
}

function hideSpinner() {
  document.getElementById("oracles-spinner").hidden = true;
  document.getElementById("submit-oracle").disabled = false;
}

function changeFlightStatus(flight, status, newTime) {
  console.log(status);
  var row = DOM.elid(flight);
  row.deleteCell(3);
  row.deleteCell(2);
  var cell3 = row.insertCell(2);
  var cell4 = row.insertCell(3);
  let statusText = "";
  switch (status) {
    case "10":
      statusText = "ON TIME";
      cell3.style = "color:white";
      cell4.style = "color:green";
      break;
    case "20":
      statusText = "LATE AIRLINE";
      cell3.style = "color:red";
      cell4.style = "color:red";
      break;
    case "30":
      statusText = "LATE WEATHER";
      cell3.style = "color:red";
      cell4.style = "color:yellow";
      break;
    case "40":
      statusText = "LATE TECHNICAL";
      cell3.style = "color:red";
      cell4.style = "color:yellow";
      break;
    case "50":
      statusText = "LATE OTHER";
      cell3.style = "color:red";
      cell4.style = "color:yellow";
      break;
    default:
      statusText = "UNKNOWN";
      cell3.style = "color:white";
      cell4.style = "color:white";
      break;
  }
  cell3.innerHTML = getTimeFromTimestamp(newTime);
  cell4.innerHTML = statusText;
}

function getTimeFromTimestamp(timestamp) {
  return new Date(timestamp * 1000).toLocaleTimeString("es-ES").slice(0, -3);
}
