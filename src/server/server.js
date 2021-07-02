import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import Config from './config.json';
import Web3 from 'web3';
import express from 'express';


let config = Config['localhost'];
let web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws')));
web3.eth.defaultAccount = web3.eth.accounts[0];
let flightSuretyApp = new web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
let flightSuretyData = new web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
let oracles = [];

let STATUS_CODE_UNKNOWN = 0
let STATUS_CODE_ON_TIME = 1
let STATUS_CODE_LATE_AIRLINE = 2
let STATUS_CODE_LATE_WEATHER = 3
let STATUS_CODE_LATE_TECHNICAL = 4
let STATUS_CODE_LATE_OTHER = 5
let defaultStatus = STATUS_CODE_ON_TIME;


flightSuretyApp.events.OracleRequest({
    fromBlock: 0
  }, function (error, event) {
    if (error) console.log(error)
    console.log(event)

    let index = event.returnValues.index;
    console.log(`Triggered index: ${index}`);
    let idx = 0;

});

function submitOracleResponse(oracle, index, airline, flight, timestamp) {
  let payload = {
    index, 
    airline,
    flight, 
    timestamp, 
    statusCode: defaultStatus
  }
  flightSuretyApp
    .methods
    .submitOracleResponse(
      index, 
      airlnie, 
      flight, 
      timestamp, 
      defaultStatus
    ).send({ 
        from: oracle, 
        gas: 500000, 
        gasPrice: 2000000
      }, 
      (error, result) => error ? console.error(error, payload) : null
    );

  if (defaultStatus == STATUS_CODE_LATE_AIRLINE) {
    flightSuretyData.methods.credInsurees(flight).call({ from: oracle }, (error, result) => {
      if (error) console.error(error, payload);
      else console.log('Insurance pay out complete.');
    })
  }
}

function getOracles() {

}

function initializeOracles() {
  return new Promise((resolve, reject) => {
    flightSuretyApp.methods.REGISTRATION_FEE().call().then(fee => {
      for (let i = 0; i < 3; i++) {
        flightSuretyApp.methods.registerOracle().send({
          from: accounts[i],

        }).then(result => {
          console.log(`Oracle ${i} registered for ${accounts[i]} with ${result} indices`);

        }).catch(err => reject(err))
      }
    }).catch(err => reject(err))
    resolve(oraclesIndexList);
  }).catch(err => reject(err));
}

const app = express();
// app.use(cors());

app.listen(80, () => console.log('web server listening on port 80'));

app.get('/api', (req, res) => {
    res.send({
      message: 'An API for use with your Dapp!'
    })
});

app.get('./api/status/:status', (req, res) => {
  let status = req.params.status;
  let message = 'Status changed to: ';
  switch(status) {
    case '1':
      defaultStatus = STATUS_CODE_ON_TIME;
      message.concat('ON TIME');
      break;
    case '2':
      defaultStatus = STATUS_CODE_LATE_AIRLINE;
      message.concat('LATE AIRLINE');
      break;
    case '3':
      defaultStatus = STATUS_CODE_LATE_WEATHER;
      message.concat('LATE WEATHER');
      break;
    case '4':
      defaultStatus = STATUS_CODE_LATE_TECHNICAL;
      message.concat('LATE TECHNICAL');
      break;
    case '5':
      defaultStatus = STATUS_CODE_LATE_OTHER;
      message.concat('LATE OTHER');
      break;
    default:
      defaultStatus = STATUS_CODE_UNKNOWN;
      message.concat('UNKNOWN');
      break;
  }
  res.send({
    message
  })
})







getOracles().then(oracles => {
  initializeOracles(oracles).catch(err => reject(err));
});

export default app;


