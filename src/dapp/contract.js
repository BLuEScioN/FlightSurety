import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import FlightSuretyData from "../../build/contracts/FlightSuretyData.json";

import Config from "./config.json";
import Web3 from "web3";

const gancheAddressesExcludingContractOwner = [
  { address: "0x03cf3b49148b6e34c241eea65a95e873f9c80573", name: "second" },
  { address: "0x8f4eF69757745e4038d74c9fdF50D942b40824AF", name: "third" },
  { address: "0xC1b4580d1b282563DedFBd518AC2FEB206bedEEd", name: "fourth" },
  { address: "0x822A2d8C03C7cD15960312006a9077e2435560B9", name: "fifth" },
  { address: "0x8848c6D645999b43c11fc5D7EE168E2144c80A99", name: "sixth" },
];

const allAirlineAddresses = [
  "0x9eB378a3413635D6da45E027451a8c8a96b191FC",
  "0x03cf3b49148b6e34c241eea65a95e873f9c80573",
  "0x8f4eF69757745e4038d74c9fdF50D942b40824AF",
  "0xC1b4580d1b282563DedFBd518AC2FEB206bedEEd",
  "0x822A2d8C03C7cD15960312006a9077e2435560B9",
  "0x8848c6D645999b43c11fc5D7EE168E2144c80A99",
];

export default class Contract {
  constructor(network, callback) {
    this.config = Config[network];
    this.web3;
    this.flightSuretyApp;
    this.flightSuretyData;
    this.accounts;
    this.activeAccount;
    this.owner;
    this.airlineAddresses = [];
    this.airlines = [];
    this.flights = [];
    this.passengers = [];
    this.eventSubscription;
    this.otherGanacheAccountIndex = 0;

    this.initializeWeb3();
    this.initializeAccounts(callback);
    this.initializeFlightSuretySmartContracts();
    this.subscribeToEvents();
    callback(); // adds event listeners for the DOM

    // this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
    // this.flightSuretyApp = new this.web3.eth.Contract(
    //   FlightSuretyApp.abi,
    //   config.appAddress
    // );
  }

  async initializeWeb3() {
    let web3Provider;

    if (typeof window.ethereum !== "undefined") {
      console.log("MetaMask is installed!");
    }

    if (window.ethereum) {
      web3Provider = window.ethereum;
      this.web3 = new Web3(web3Provider);
      try {
        // Request account access
        console.log("request account access");
        window.ethereum.enable();
        console.log("ethereum window enabled");
      } catch (error) {
        // User denied account access...
        console.error("User denied account access");
      }
    }
    // Legacy dapp browsers...
    else if (window.web3) {
      web3Provider = window.web3.currentProvider;
      this.web3 = new Web3(web3Provider);
      console.log("currrent provider web3: " + web3Provider);
    }
    // If no injected web3 instance is detected, fall back to Ganache
    else {
      //   web3Provider = new Web3.providers.WebsocketProvider(
      //     this.config.url.replace("http", "ws")
      //   ); // WS
      web3Provider = new Web3(new Web3.providers.HttpProvider(this.config.url)); // HTTP
    }

    // web3Provider = new Web3(new Web3.providers.HttpProvider(this.config.url)); // HTTP
    // web3Provider = new Web3.providers.WebsocketProvider(
    //   this.config.url.replace("http", "ws")
    // ); // WS
    // this.web3 = new Web3(web3Provider);

    // console.log(
    //   "web3: " + JSON.stringify(this.web3.eth.Contract.defaultAccount)
    // );
    console.log("web3 instantiated in contract");

    // return web3;
    // this.initializeAccounts();
  }

  async initializeAccounts(callback) {
    const accounts = await this.web3.eth.getAccounts((error, accounts) => {
      console.log("contract.js, initializeAccounts", { error, accounts });
      if (error) console.error(error);

      this.accounts = accounts;
      this.owner = accounts[0];

      this.airlineAddresses.push(this.owner); // owner is contract owner of app and data contracts and becomes 1st airline

      // console.log("FE, initializeAccounts", { owner: this.owner }); // delete

      // let counter = 1;

      // while (this.airlineAddresses.length < 5) {
      //   this.airlineAddresses.push(accounts[counter++]);
      // }
      // console.log("FE, initializeAccounts", {
      //   airlines: this.airlineAddresses,
      // }); // delete

      // while (this.passengers.length < 5) {
      //   this.passengers.push(accounts[counter++]);
      // }
      // console.log("FE, initializeAccounts", { passengers: this.passengers }); // delete
    });
    console.log({ accounts });
  }

  initializeFlightSuretySmartContracts() {
    this.flightSuretyApp = new this.web3.eth.Contract(
      FlightSuretyApp.abi,
      this.config.appAddress
    );
    this.flightSuretyData = new this.web3.eth.Contract(
      FlightSuretyData.abi,
      this.config.dataAddress
    );
    console.log("flight surety app contract address:", this.config.appAddress);
    console.log(
      "flight surety data contract address:",
      this.config.dataAddress
    );
  }

  subscribeToEvents() {
    this.eventSubscription = this.web3.eth
      .subscribe(
        "logs",
        {
          address: [this.config.appAddress],
        },
        (error, result) => {
          if (error) console.error("FE, subscribeToEvents", error);
          console.log("FE, subscribeToEvents", { result });
        }
      )
      .on("data", (log) =>
        console.log("FE, subscribeToEvents, on data", {
          log,
          //   decoded: this.web3.eth.abi.decodeLog(),
        })
      )
      .on("changed", (log) =>
        console.log("FE, subscribeToEvents, on change", { log })
      );
  }

  // subscribeToEvents() {
  //   this.eventSubscription = this.web3.eth
  //     .subscribe(
  //       "logs",
  //       {
  //         address: [this.config.dataAddress],
  //       },
  //       (error, result) => {
  //         if (error) console.error("FE, subscribeToEvents", error);
  //         console.log("FE, subscribeToEvents", { result });
  //       }
  //     )
  //     .on("data", (log) => {
  //       const decodedLog = this.web3.eth.abi.decodeLog(
  //         FlightSuretyData.abi,
  //         log?.data,
  //         log?.topics
  //       );
  //       console.log("FE, subscribeToEvents, on data", {
  //         log,
  //         decodedLog,
  //         //   decoded: this.web3.eth.abi.decodeLog(),
  //       });
  //     })
  //     .on("changed", (log) =>
  //       console.log("FE, subscribeToEvents, on change", { log })
  //     );
  // }

  checkContractsAreOperational() {
    this.flightSuretyApp.methods
      .isOperational()
      .call({ from: owner })
      .then(function(result) {
        console.log("isOperational: " + result);
      })
      .catch(function(err) {
        "error: " + err;
      });

    this.flightSuretyData.methods
      .isOperational()
      .call({ from: owner })
      .then(function(result) {
        console.log("isOperational: " + result);
      })
      .catch(function(err) {
        "error: " + err;
      });
  }

  /********************************************************************************************/
  //                                     LOGGING
  /********************************************************************************************/

  async logAirlines() {
    const airlines = await this.getAirlines();
    console.log("logAirlines", { airlines });
  }

  async logAuthorizedAirlines() {
    const authorizedAirlines = [];
    const numAuthorizedAirlines = await this.flightSuretyData.methods
      .numAuthorizedAirlines()
      .call({ from: this.owner });
    for (let i = 0; i < numAuthorizedAirlines; i++) {
      const authorizedAirline = await this.flightSuretyData.methods
        .authorizedAirlinesArray(i)
        .call({ from: this.owner });
      authorizedAirlines.push(authorizedAirline);
    }
    console.log("logAuthorizedAirlines", { authorizedAirlines });
  }

  async logDataOwner() {
    const contractOwner = await this.flightSuretyData.methods
      .contractOwner()
      .call({ from: this.owner });
    console.log("logDataOwner", { contractOwner });
  }

  async logAppOwner() {
    const contractOwner = await this.flightSuretyApp.methods
      .contractOwner()
      .call({ from: self.owner });
    console.log("logAppOwner", { contractOwner });
  }

  async logFlights() {
    const flightNames = [];
    const flights = [];
    const numFlights = await this.flightSuretyData.methods
      .numFlights()
      .call({ from: this.owner });
    for (let i = 0; i < numFlights; i++) {
      const flightName = await this.flightSuretyData.methods
        .flightNameArray(i)
        .call({ from: this.owner });
      flightNames.push(flightName);
    }
    for (let i = 0; i < numFlights; i++) {
      const flight = await this.flightSuretyData.methods
        .flights(flightNames[i])
        .call({ from: this.owner });
      flights.push(flight);
    }
    console.log("logFlights", { flightNames, flights });
  }

  async logPassengers() {
    const passengerAddresses = [];
    const passengers = [];
    const numPassengers = await this.flightSuretyData.methods
      .numPassengers()
      .call({ from: this.owner });
    for (let i = 0; i < numPassengers; i++) {
      const flightName = await this.flightSuretyData.methods
        .passengerAddresses(i)
        .call({ from: this.owner });
      passengerAddresses.push(flightName);
    }
    for (let i = 0; i < numPassengers; i++) {
      const passenger = await this.flightSuretyData.methods
        .passengers(passengerAddresses[i])
        .call({ from: this.owner });
      passengers.push(passenger);
    }
    console.log("logPassengers", { passengerAddresses, passengers });
  }

  async logAppBalance() {
    const balance = await this.web3.eth.getBalance(this.config.appAddress);
    console.log("logAppBalance", { balance });
  }

  async logDataBalance() {
    const balance = await this.web3.eth.getBalance(this.config.dataAddress);
    console.log("logDataBalance", { balance });
  }

  async logVotes() {
    let votes = {};
    for (let i = 0; i < allAirlineAddresses.length; i++) {
      for (let j = 0; j < allAirlineAddresses.length; j++) {
        const voter = allAirlineAddresses[i];
        const votee = allAirlineAddresses[j];
        if (i === j) continue;
        const voteRecord = await this.flightSuretyData.methods
          .airlineVotes(voter, votee)
          .call({ from: this.owner });
        if (!(voter in votes)) votes[voter] = {};
        votes[voter][votee] = voteRecord;
      }
    }
    console.log("logVote", { votes });
  }

  /********************************************************************************************/
  //                                     AIRLINE ACTIONS
  /********************************************************************************************/

  async registerAirline(address, name, callback) {
    // For quick manual testing. Uses predefined addresses and names for registering airlines
    if (address === "" || name === "") {
      if (
        this.otherGanacheAccountIndex <
        gancheAddressesExcludingContractOwner.length
      ) {
        address =
          gancheAddressesExcludingContractOwner[this.otherGanacheAccountIndex]
            .address;
        name =
          gancheAddressesExcludingContractOwner[this.otherGanacheAccountIndex]
            .name;
        this.otherGanacheAccountIndex++;
      } else {
        console.error(
          "No more ganache accounts stored. Please add more Ganache Accounts."
        );
      }
    }

    callback = callback
      ? callback
      : () => {
          console.log(
            `airline with address ${address} and name ${name} registered successfully`
          );
          this.airlineAddresses.push(address);
        };
    await this.flightSuretyApp.methods
      .registerAirline(address, name)
      .send({ from: this.owner, gas: Config.gas }, callback);
  }

  async vote(airlineAddress) {
    this.flightSuretyApp.methods
      .vote(airlineAddress)
      .send({ from: await this.getActiveAccount(), gas: Config.gas });
  }

  // FIXME: VM Exception. Send Ether.
  async fund(funds) {
    let value = this.web3.utils.toWei(funds.toString(), "ether");
    this.flightSuretyApp.methods.fund().send({
      from: await this.getActiveAccount(),
      gas: Config.gas,
      value: value,
    });
  }

  // PROVIDED
  isOperational(callback) {
    this.flightSuretyApp.methods
      .isOperational()
      .call({ from: this.owner }, callback);
  }

  /********************************************************************************************/
  //                                     FLIGHT ACTIONS
  /********************************************************************************************/

  async registerFlight(airline, flight, departureTime, price) {
    // consider putting into object and destructuring here
    this.flightSuretyApp.methods
      .registerFlight(airline, flight, departureTime, price)
      .send({ from: await this.getActiveAccount(), gas: Config.gas });
  }

  /********************************************************************************************/
  //                                     PASSENGER ACTIONS
  /********************************************************************************************/

  async buyFlightInsurance(flightId, payment) {
    let priceInWei = this.web3.utils.toWei(payment.toString(), "ether");

    this.flightSuretyApp.methods.buyFlightInsurance(flightId).send({
      from: await this.getActiveAccount(),
      value: priceInWei,
      gas: Config.gas,
    });
  }

  async withdrawFlightInsurancePayout() {
    this.flightSuretyData.methods
      .withdraw(await this.getActiveAccount())
      .send({ from: await this.getActiveAccount(), gas: Config.gas });
  }

  /********************************************************************************************/
  //                                     ORACLE ACTIONS
  /********************************************************************************************/

  async fetchFlightStatus(flightId) {
    const flightInfo = await this.getFlightInfo(flightId);
    const airlines = await this.getAirlines();
    const airline = airlines.filter(
      (airline) =>
        airline.name.toLowerCase() === flightInfo.airline.toLowerCase()
    )[0];
    const airlineAddress = airline?.account;
    console.log("fetchFlightStatus", {
      flightInfo,
      airlines,
      airline,
      airlineAddress,
    });
    await this.flightSuretyApp.methods
      .fetchFlightStatus(airlineAddress, flightId, flightInfo.departureTime)
      .send({ from: await this.getActiveAccount(), gas: Config.gas });
  }

  async getFlightInfo(flightId) {
    const flightInfo = await this.flightSuretyData.methods
      .flights(flightId)
      .call({ from: this.owner });
    return flightInfo;
  }

  async getAirlines() {
    const airlineAddresses = [];
    const airlines = [];
    const numAirlines = await this.flightSuretyData.methods
      .numAirlines()
      .call({ from: this.owner });
    for (let i = 0; i < numAirlines; i++) {
      const airlineAddress = await this.flightSuretyData.methods
        .airlineAddresses(i)
        .call({ from: this.owner });
      airlineAddresses.push(airlineAddress);
    }
    for (let i = 0; i < numAirlines; i++) {
      const airline = await this.flightSuretyData.methods
        .airlines(airlineAddresses[i])
        .call({ from: this.owner });
      airlines.push(airline);
    }
    return airlines;
  }

  viewFlightStatus(airline, flight, callback) {
    this.flightSuretyApp.methods
      .viewFlightStatus(flight, airline)
      .call({ from: self.accounts[0] }, (error, result) => {
        callback(error, result);
      });
  }

  async setFlightStatus(flightId, statusCode) {}

  /********************************************************************************************/
  //                                     UTILITY FUNCTIONS
  /********************************************************************************************/

  // TODO: Search Solidity docs for some subscription to account changes
  async getActiveAccount() {
    let activeAccount;
    await this.web3.eth.getAccounts((error, accounts) => {
      activeAccount = accounts[0];
    });
    return activeAccount;
  }
}
