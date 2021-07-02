import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';

export default class Contract {
    constructor(network, callback) {
        let config = Config[network];
        this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.initialize(callback);
        this.owner = null;
        this.airlines = [];
        this.passengers = [];
    }

    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
            this.owner = accts[0];

            let counter = 1;
            
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            callback();
        });
    }

    isOperational(callback) {
       let self = this;
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    fetchFlightStatus(flight, callback) {
        let self = this;
        let payload = {
            airline: self.airlines[0],
            flight: flight,
            timestamp: Math.floor(Date.now() / 1000)
        } 
        self.flightSuretyApp.methods
            .fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
            .send({ from: self.owner}, (error, result) => {
                callback(error, payload);
            });
    }

    viewFlightStatus(airline, flight, callback) {
        this.flightSuretyApp.methods
            .viewFlightStatus(flight, airline)
            .call({ from: self.accounts[0]}, (error, result) => {
                callback(error, result);
            })
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

    async fund(
        funds,
        callback
    ) {
        let self = this;
        let value = this.web3.utils.toWei(funds.toString(), "ether");
        let payload = {
            funds: value,
            funder: 0x00,
            active: "false"
        } 
        await this.web3.eth.getAccounts((error, accts) => {
            payload.funder = accts[0];
        });
        self.flightSuretyData.methods
            .fund()
            .send({ from: payload.funder, value: value}, (error, result) => {
                if (!error){
                    self.flightSuretyData.methods.
                    isActive(payload.funder).call({ from: payload.funder}, (error, result) => {
                        if(!error){
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
            timestamp: Math.floor(Date.now() / 1000)
        }
        await this.web3.eth.getAccounts((error, accounts) => {
            self.accounts = accounts;
        });
        self.flightSuretyApp.methods
            .registerFlight(payload.flight, payload.destination, payload.timestamp)
            .send({ from: self.accounts[0],
                gas: 5000000,
                gasPrice: 20000000}, 
                (error, result) => callback(error, payload)
            );
    }

    async buy(flight, price, callback) {
        let self = this;
        let priceInWei = this.web3.utils.toWei(price.toString(), "ether");
        let payload = {
            flight: flight,
            price: priceInWei,
            passenger: self.accounts[0]
        } 
        await this.web3.eth.getAccounts((error, accounts) => {
            payload.passenger = accounts[0];
        });
        self.flightSuretyData.methods
            .buy(flight)
            .send(
                { 
                    from: payload.passenger, 
                    value: priceInWei,
                    gas: 500000,
                    gasPrice: 1
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
        await this.web3.eth.getAccounts((error, accounts) => self.accounts = accounts );
        self.flightSuretyData.methods.
            withdraw(self.accounts[0]).send(
                { from: self.accounts[0]}, 
                (error, result) => callback(error, result)
            );
    }
}