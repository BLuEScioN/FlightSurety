import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import FlightSuretyData from "../../build/contracts/FlightSuretyData.json";

import Config from "./config.json";
import Web3 from "web3";

export default class Contract {
  constructor(network, callback) {
    this.config = Config[network];
    this.web3;
    this.flightSuretyApp;
    this.flightSuretyData;
    this.accounts;
    this.owner;
    this.airlines = [];
    this.flights = [];
    this.passengers = [];
    this.eventSubscription;

    this.initializeWeb3();
    this.initializeAccounts(callback);
    this.initializeFlightSuretySmartContracts();
    this.subscribeToEvents();
    // callback(); // adds event listeners for the DOM

    // this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
    // this.flightSuretyApp = new this.web3.eth.Contract(
    //   FlightSuretyApp.abi,
    //   config.appAddress
    // );
  }

  async initializeWeb3() {
    let web3Provider;

    if (window.ethereum) {
      web3Provider = window.ethereum;
      try {
        // Request account access
        console.log("request account access");
        await window.ethereum.enable();
        console.log("ethereum window enabled");
      } catch (error) {
        // User denied account access...
        console.error("User denied account access");
      }
    }
    // Legacy dapp browsers...
    else if (window.web3) {
      web3Provider = window.web3.currentProvider;
      console.log("currrent provider web3: " + web3Provider);
    }
    // If no injected web3 instance is detected, fall back to Ganache
    else {
      web3Provider = new Web3.providers.WebsocketProvider(
        this.config.url.replace("http", "ws")
      ); // WS
    }

    // web3Provider = new Web3(new Web3.providers.HttpProvider(this.config.url)); // HTTP
    // web3Provider = new Web3.providers.WebsocketProvider(
    //   this.config.url.replace("http", "ws")
    // ); // WS

    this.web3 = new Web3(web3Provider);

    // console.log(
    //   "web3: " + JSON.stringify(this.web3.eth.Contract.defaultAccount)
    // );
    console.log("web3 instantiated in contract");

    // this.initializeAccounts();
  }

  initializeAccounts(callback) {
    this.web3.eth.getAccounts((error, accounts) => {
      this.accounts = accounts;
      this.owner = accounts[0];
      console.log("FE, initializeAccounts", { owner: this.owner }); // delete

      let counter = 1;

      while (this.airlines.length < 5) {
        this.airlines.push(accounts[counter++]);
      }
      console.log("FE, initializeAccounts", { airlines: this.airlines }); // delete

      while (this.passengers.length < 5) {
        this.passengers.push(accounts[counter++]);
      }
      console.log("FE, initializeAccounts", { passengers: this.passengers }); // delete

      callback(); // adds event listeners for the DOM
    });
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
          address: [this.config.appAddress, this.config.dataAddress],
        },
        (error, result) => {
          if (error) console.error("FE, subscribeToEvents", error);
          console.log("FE, subscribeToEvents", { result });
        }
      )
      .on("data", (log) =>
        console.log("FE, subscribeToEvents, on data", { log })
      )
      .on("changed", (log) =>
        console.log("FE, subscribeToEvents, on change", { log })
      );
  }

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

  logAirlines() {
    // this.FlightSuretyData;
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
    console.log("FlightSuretyData authorizedAirlines are", authorizedAirlines);
  }

  async logDataOwner() {
    const contractOwner = await this.flightSuretyData.methods
      .contractOwner()
      .call({ from: this.owner });
    console.log("FlightSuretyData contractOwner is", contractOwner);
  }

  async logAppOwner() {
    const contractOwner = await this.flightSuretyApp.methods
      .contractOwner()
      .call({ from: self.owner });
    console.log("FlightSuretyApp contractOwner is", contractOwner);
  }

  /********************************************************************************************/
  //                                     AIRLINE ACTIONS
  /********************************************************************************************/

  registerAirline(address, name, callback) {
    console.log("calling registerAirline", {
      owner: this.owner,
      address,
      name,
    });
    callback = callback
      ? callback
      : () =>
          console.log(`airline (${address}) ${name} registered successfully`);
    this.flightSuretyApp.methods
      .registerAirline(address, name)
      .call({ from: this.owner, gas: Config.gas }, callback);
  }

  // async getAirlines() {
  //     let self = this;
  //     const airlines = await self.flightSuretyData.methods
  //          .getAirlines()
  //          .call({ from: self.owner, gas: config.gas}, callback);
  //     console.log('contract.js, getAirlines', {airlines})
  // }

  isOperational(callback) {
    let self = this;
    self.flightSuretyApp.methods
      .isOperational()
      .call({ from: self.owner }, callback);
  }

  fetchFlightStatus(flight, callback) {
    let self = this;
    let payload = {
      airline: self.airlines[0],
      flight: flight,
      timestamp: Math.floor(Date.now() / 1000),
    };
    self.flightSuretyApp.methods
      .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
      .send({ from: self.owner }, (error, result) => {
        callback(error, payload);
      });
  }

  viewFlightStatus(airline, flight, callback) {
    this.flightSuretyApp.methods
      .viewFlightStatus(flight, airline)
      .call({ from: self.accounts[0] }, (error, result) => {
        callback(error, result);
      });
  }

  // async registerAirline(airlineAddress, airlineName, sender, callback) {
  //     let payload = {
  //         airlineAddress,
  //         airlineName,
  //         sender
  //     }
  //     await this.web3.eth.getAccounts((error, accounts) => {
  //         payload.sender = accounts[0];
  //     });
  //     this.flightSuretyApp.methods
  //         .registerAirline(payload.airlineAddress, payload.airlineName)
  //         .send({
  //             from: sender,
  //             gas: 5000000,
  //             gasPrice: 2000000
  //         }, (error, result) => {
  //             if (error) {
  //                 console.error(error);
  //                 callback(error, payload);
  //             } else {
  //                 this.flightSuretyData.methods
  //                     .isRegistered(payload.airlineAddress).call({ from: payload.sender }, (error, result) => {
  //                         if (error || result.toString() == 'false') {
  //                             payloadMessage = 'New airline needs at least 4 votes to get registered.';
  //                             payload.registered = false;
  //                             callback(error, payload);
  //                         } else {
  //                             payload.message = `Registered ${payload.airlineAddress} as ${payload.airlineName}.`;
  //                             payload.registered = true;
  //                             callback(error, payload);
  //                         }
  //                     })
  //             }
  //         })
  // }

  async fund(funds, callback) {
    let self = this;
    let value = this.web3.utils.toWei(funds.toString(), "ether");
    let payload = {
      funds: value,
      funder: 0x00,
      active: "false",
    };
    await this.web3.eth.getAccounts((error, accts) => {
      payload.funder = accts[0];
    });
    self.flightSuretyData.methods
      .fund()
      .send({ from: payload.funder, value: value }, (error, result) => {
        if (!error) {
          self.flightSuretyData.methods
            .isActive(payload.funder)
            .call({ from: payload.funder }, (error, result) => {
              if (!error) {
                payload.active = result;
              }
              callback(error, payload);
            });
        }
      });
  }

  async registerFlight(flight, destination, callback) {
    let self = this;
    let payload = {
      flight,
      destination,
      timestamp: Math.floor(Date.now() / 1000),
    };
    await this.web3.eth.getAccounts((error, accounts) => {
      self.accounts = accounts;
    });
    self.flightSuretyApp.methods
      .registerFlight(payload.flight, payload.destination, payload.timestamp)
      .send(
        { from: self.accounts[0], gas: 5000000, gasPrice: 20000000 },
        (error, result) => callback(error, payload)
      );
  }

  async buy(flight, price, callback) {
    let self = this;
    let priceInWei = this.web3.utils.toWei(price.toString(), "ether");
    let payload = {
      flight: flight,
      price: priceInWei,
      passenger: self.accounts[0],
    };
    await this.web3.eth.getAccounts((error, accounts) => {
      payload.passenger = accounts[0];
    });
    self.flightSuretyData.methods.buy(flight).send(
      {
        from: payload.passenger,
        value: priceInWei,
        gas: 500000,
        gasPrice: 1,
      },
      (error, result) => callback(error, payload)
    );
  }

  // async getCreditToPay(callback) {
  //     let self = this;
  //     await this.web3.eth.getAccounts((error, accounts) => {
  //         self.accounts = accounts;
  //     });
  //     self.flightSuretyData.methods.
  //         getCreditToPay().call(
  //             { from: self.accounts[0] },
  //             (error, result) => callback(error, result)
  //         );
  // }

  async pay(callback) {
    let self = this;
    await this.web3.eth.getAccounts(
      (error, accounts) => (self.accounts = accounts)
    );
    self.flightSuretyData.methods
      .withdraw(self.accounts[0])
      .send({ from: self.accounts[0] }, (error, result) =>
        callback(error, result)
      );
  }
}
