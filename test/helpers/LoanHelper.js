import BigNumber from 'bignumber.js';
import Web3 from 'web3';
import promisify from 'es6-promisify';
import ethUtil from 'ethereumjs-util';
import {
  ADDRESSES,
  BIGNUMBERS,
  DEFAULT_SALT,
  SIGNATURE_TYPE,
} from './Constants';

const HeldToken = artifacts.require('TokenA');
const OwedToken = artifacts.require('TokenB');
const FeeToken = artifacts.require('TokenC');
const Margin = artifacts.require('Margin');

const web3Instance = new Web3(web3.currentProvider);

export async function createLoanOffering(
  accounts,
  {
    salt = DEFAULT_SALT,
    interestPeriod,
  } = {},
) {
  const loanOffering = {
    owedToken: OwedToken.address,
    heldToken: HeldToken.address,
    payer: accounts[1],
    owner: accounts[1],
    taker: ADDRESSES.ZERO,
    positionOwner: ADDRESSES.ZERO,
    feeRecipient: accounts[3],
    lenderFeeTokenAddress: FeeToken.address,
    takerFeeTokenAddress: FeeToken.address,
    rates: {
      maxAmount:          new BigNumber('3098765432109876541'),
      minAmount:          new BigNumber('123456789012345789'),
      minHeldToken:       new BigNumber('11098765432109871111'),
      lenderFee:          new BigNumber('11098765432109871'),
      takerFee:           new BigNumber('21098765432109871'),
      interestRate:       new BigNumber('3650101'), // ~3.65% nominal per year
      interestPeriod:     interestPeriod || BIGNUMBERS.ONE_DAY_IN_SECONDS,
    },
    expirationTimestamp:  1000000000000, // 31.69 millennia from 1970
    callTimeLimit: 10000,
    maxDuration: 365 * BIGNUMBERS.ONE_DAY_IN_SECONDS.toNumber(),
    salt,
  };

  loanOffering.signature = await signLoanOffering(loanOffering);

  return loanOffering;
}

export function setLoanHash(loanOffering) {
  const valuesHash = web3Instance.utils.soliditySha3(
    loanOffering.rates.maxAmount,
    loanOffering.rates.minAmount,
    loanOffering.rates.minHeldToken,
    loanOffering.rates.lenderFee,
    loanOffering.rates.takerFee,
    loanOffering.expirationTimestamp,
    loanOffering.salt,
    { type: 'uint32', value: loanOffering.callTimeLimit },
    { type: 'uint32', value: loanOffering.maxDuration },
    { type: 'uint32', value: loanOffering.rates.interestRate },
    { type: 'uint32', value: loanOffering.rates.interestPeriod },
  );
  const hash = web3Instance.utils.soliditySha3(
    Margin.address,
    loanOffering.owedToken,
    loanOffering.heldToken,
    loanOffering.payer,
    loanOffering.owner,
    loanOffering.taker,
    loanOffering.positionOwner,
    loanOffering.feeRecipient,
    loanOffering.lenderFeeTokenAddress,
    loanOffering.takerFeeTokenAddress,
    valuesHash,
  );

  loanOffering.loanHash = hash;
}

export async function signLoanOffering(loanOffering) {
  setLoanHash(loanOffering);

  const signature = await promisify(web3Instance.eth.sign)(
    loanOffering.loanHash,
    loanOffering.payer,
  );

  const { v, r, s } = ethUtil.fromRpcSig(signature);
  return ethUtil.bufferToHex(
    Buffer.concat([
      ethUtil.toBuffer(SIGNATURE_TYPE.DEC),
      ethUtil.toBuffer(v),
      r,
      s,
    ]),
  );
}
