import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import FlightSuretyData from "../../build/contracts/FlightSuretyData.json";
import Config from "./config.json";
import Web3 from "web3";
import express from "express";
import cors from "cors";
import "babel-polyfill";
import HDWalletProvider from "@truffle/hdwallet-provider";
import fs from "fs";
// var HDWalletProvider = require("@truffle/hdwallet-provider");
// const fs = require("fs");

/********************************************************************************************/
//                                    INITIALIZATION WEB3
/********************************************************************************************/

// GANACHE
// const config = Config["localhost"];
// const ganacheWeb3Provider = new Web3.providers.WebsocketProvider(config.url.replace("http", "ws"));
// const web3 = new Web3(ganacheWeb3Provider);

// RINKEBY
const config = Config["rinkeby"];
console.log({ rinkebyConfig: config });
const testMetaMaskMnemonic = fs
  .readFileSync(".secret-metamask-mnemonic")
  .toString()
  .trim();
console.log({ testMetaMaskMnemonic });
const infuraKey = fs
  .readFileSync(".secret-infura-key")
  .toString()
  .trim();
console.log({ infuraKey });
const hdWalletProvider = new HDWalletProvider(
  testMetaMaskMnemonic,
  `wss://rinkeby.infura.io/ws/v3/${infuraKey}`
);
const web3 = new Web3(hdWalletProvider);

// const infurarWeb3Provider = new Web3.providers.WebsocketProvider(
//   `wss://rinkeby.infura.io/ws/v3/${infuraKey}`
// );
// const web3 = new Web3(infurarWeb3Provider);

/********************************************************************************************/
//                                    INITIALIZATION CONTRACTS
/********************************************************************************************/

let flightSuretyAppContract = new web3.eth.Contract(
  FlightSuretyApp.abi,
  config.appAddress
);
let flightSuretyDataContract = new web3.eth.Contract(
  FlightSuretyData.abi,
  config.dataAddress
);

/********************************************************************************************/
//                                    ORACLE INITIALIZATION CODE
/********************************************************************************************/

let oracles = [];
const oracleCount = 10;

let STATUS_CODE_UNKNOWN = 0;
let STATUS_CODE_ON_TIME = 10;
let STATUS_CODE_LATE_AIRLINE = 20;
let STATUS_CODE_LATE_WEATHER = 30;
let STATUS_CODE_LATE_TECHNICAL = 40;
let STATUS_CODE_LATE_OTHER = 50;
let defaultStatus = STATUS_CODE_ON_TIME;

async function getOracleAccounts() {
  const accounts = await web3.eth.getAccounts();
  console.log("server.js, getOracleAccounts", { accounts });
  const oracleAccounts = accounts.slice(10, 10 + oracleCount);
  console.log("server.js, getOracleAccounts", { oracleAccounts });

  return oracleAccounts;
}

async function initializeOracles() {
  try {
    const oracleAccounts = await getOracleAccounts();
    const fee = await flightSuretyAppContract.methods
      .REGISTRATION_FEE()
      .call({ from: oracleAccounts[0] });

    for (let i = 0; i < oracleCount; i++) {
      const oracle = oracleAccounts[i];
      await flightSuretyAppContract.methods
        .registerOracle()
        .send({ from: oracle, value: fee, gas: config.gas });
      const indices = await flightSuretyAppContract.methods
        .getMyIndexes()
        .call({ from: oracle });
      console.log(
        `Oracle ${i} (${oracle}) registered with indices, ${indices}`
      );
    }
  } catch (err) {
    console.error(err);
  }
}

// initialize server
initializeOracles();

/********************************************************************************************/
//                                    EVENT CODE
/********************************************************************************************/

// Just log all flightSuretyDataContract events
flightSuretyDataContract.events.allEvents(
  {
    fromBlock: "latest",
  },
  function(error, event) {
    if (error) {
      console.log("error");
      console.log(error);
    } else {
      console.log("event:");
      console.log(event);
    }
  }
);

/********************************************************************************************/
//                                    ORACLE CODE
/********************************************************************************************/

/**
 * When the flight surety app contract makes an oracle request, the server pretends to be all the oracles,
 * for each oracle that is responsible for random index that is sent along with the oracle request they generate a
 * random flight status and send that back to the smart contract as their response
 */
flightSuretyAppContract.events.OracleRequest(
  {
    fromBlock: "latest",
  },
  function(error, event) {
    if (error) console.error(error);
    console.log("Server.js, Oracle Request event detected", { event });
    const { index, flight, airline, timestamp } = event.returnValues;
    console.log(
      `Requesting data from oracles registed to service index: ${index}`
    );

    for (let oracle of oracles) {
      const account = oracle.account ?? "undefined";
      const indices = oracle.indices ?? [];
      if (indices.includes(index)) {
        const flightStatus = getRandomFlightStatus();
        console.log(
          `oracle ${oracle.account} with indices ${indices} responding with flightStatus ${flightStatus}`
        );
        submitOracleResponse(
          account,
          index,
          airline,
          flight,
          timestamp,
          statusCode
        );
      }
    }
  }
);

function submitOracleResponse(
  oracle,
  index,
  airline,
  flight,
  timestamp,
  statusCode
) {
  flightSuretyAppContract.methods
    .submitOracleResponse(index, airline, flight, timestamp, statusCode)
    .send({
      from: oracle,
      gas: config.gas,
    });
}

function getRandomFlightStatus() {
  return Math.floor(Math.random() * (50 - 10 + 1) + 0); // Formula for getting a random integer between two values, inclusive: Math.floor(Math.random() * (max - min + 1) + min)
}

/********************************************************************************************/
//                                    CREAT AND EXPORT SERVER CODE
/********************************************************************************************/

const app = express();
app.use(cors());

app.get("/api", (req, res) => {
  res.send({
    message: "An API for use with your Dapp!",
  });
});

export default app;

// app.get('./api/status/:status', (req, res) => {
//   let status = req.params.status;
//   let message = 'Status changed to: ';
//   switch(status) {
//     case '1':
//       defaultStatus = STATUS_CODE_ON_TIME;
//       message.concat('ON TIME');
//       break;
//     case '2':
//       defaultStatus = STATUS_CODE_LATE_AIRLINE;
//       message.concat('LATE AIRLINE');
//       break;
//     case '3':
//       defaultStatus = STATUS_CODE_LATE_WEATHER;
//       message.concat('LATE WEATHER');
//       break;
//     case '4':
//       defaultStatus = STATUS_CODE_LATE_TECHNICAL;
//       message.concat('LATE TECHNICAL');
//       break;
//     case '5':
//       defaultStatus = STATUS_CODE_LATE_OTHER;
//       message.concat('LATE OTHER');
//       break;
//     default:
//       defaultStatus = STATUS_CODE_UNKNOWN;
//       message.concat('UNKNOWN');
//       break;
//   }
//   res.send({
//     message
//   })
// })
