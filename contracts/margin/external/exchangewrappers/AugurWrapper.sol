/*

    Copyright 2018 dYdX Trading Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity 0.4.24;
pragma experimental "v0.5.0";
pragma experimental ABIEncoderV2;

import { SafeMath } from "openzeppelin-solidity/contracts/math/SafeMath.sol";
import { MathHelpers } from "../../../lib/MathHelpers.sol";
import { GeneralERC20 } from "../../../lib/GeneralERC20.sol";
import { TokenInteract } from "../../../lib/TokenInteract.sol";
import { ExchangeReader } from "../../interfaces/ExchangeReader.sol";
import { ExchangeWrapper } from "../../interfaces/ExchangeWrapper.sol";
import { IMarket } from "../../augur-core/source/contracts/reporting/IMarket.sol"

contract ITrade {
    function publicFillBestOrder(Order.TradeDirections _direction, IMarket _market, uint256 _outcome, uint256 _amount, uint256 _price, uint256 _tradeGroupID) external returns (uint256);
}

/**
 * @title AugurWrapper
 * @author dYdX
 *
 * dYdX AugurWrapper to interface with 0x Version 2
 */
/* To make shorting possible we need to check user's balance before  after by looking at different outcomes like:
        altOutcome = 0;
        if(order.outcome == 0):
            altOutcome = 1;
        
        balanceBefore = ERC20(IMarket(marketAddress).getShareToken(order.outcome)).balance(this);
        balanceBeforeAlt = ERC20(IMarket(marketAddress).getShareToken(altOutcome)).balance(this)
        ITrade(AUGUR_TRADING_CONTRACT).publicFillBestOrder(direction, marketAddress, outcome, amount, price, 0, 1, false);
        balanceAfter = ERC20(IMarket(marketAddress).getShareToken(order.outcome)).balance(this);
        balanceAfterAlt = ERC20(IMarket(marketAddress).getShareToken(altOutcome)).balance(this)
        receivedMakerTokenAmount = balanceBefore - balanceAfter;

    But we also need to set allowances for all the tokens they got as part of a short position. Then on top of that the rest of dydx would need to be rearchitected to support multiple tokens as held token 
    *or* we could spin up a new token a la set and put all these tokens into that and have a single token short position. And we'd need to so somehting like:

    function modifyPriceIfShorting(uint256 orderPrice, uint256 direction) private {
        /* if selling */
        //if(direction == 1) {
            // if amount is > shares we own we're shorting
            // for shares we own the price is the orderPrice
            // for the amount beyond that the price is numTicks - orderPrice
        //}


    //So for now this is buy only

contract AugurWrapper is
    ExchangeWrapper,
    ExchangeReader
{
    using SafeMath for uint256;
    using TokenInteract for address;

    // ============ Structs ============

    struct Order {
        address marketAddress;
        address taker;
        uint256 amount;
        uint256 price;
        uint256 direction;
        uint256 outcome;
    }

    // ============ State Variables ============

    // address of the ZeroEx V1 Exchange
    address public AUGUR_TRADING_CONTRACT;

    // address of the Augur TokenTransferProxy
    address public AUGUR_SOL;

    // ============ Constructor ============

    constructor(
        address augurTradeContract,
        address augurSolContract,
    )
        public
    {
        AUGUR_TRADING_CONTRACT = augurTradeContract;
        AUGUR_SOL  augurSolContract
    }

    // ============ Public Functions ============

    /**
     * Exchange some amount of takerToken for makerToken.
     *
     * @param  tradeOriginator      Address of the initiator of the trade (however, this value
     *                              cannot always be trusted as it is set at the discretion of the
     *                              msg.sender)
     * @param  receiver             Address to set allowance on once the trade has completed
     * @param  makerToken           Address of makerToken, the token to receive
     * @param  takerToken           Address of takerToken, the token to pay
     * @param  requestedFillAmount  Amount of takerToken being paid
     * @param  orderData            Arbitrary bytes data for any information to pass to the exchange
     * @return                      The amount of makerToken received
     */
    function exchange(
        address tradeOriginator, /* not used for AugurWrapper */
        address receiver,
        address makerToken,
        address takerToken,
        uint256 requestedFillAmount,
        bytes orderData
    )
        external
        returns (uint256)
    {
        Order memory order = parseOrder(orderData);

        require(
            requestedFillAmount <= order.amount * order.price,
            "AugurWrapper#exchange: Requested fill amount larger than submitted Augur order size"
        );

        require(
            requestedFillAmount <= takerToken.balanceOf(address(this)),
            "AugurWrapper#exchange: Requested fill amount larger than tokens held"
        );

        require(
            direction == 0,
            "Direction isn't buy / long only"
        );

        ensureAllowance(
            takerToken, /* this should be the augur cash contract usually */
            AUGUR_SOL,
            requestedFillAmount
        );

        altOutcome = 0;
        if(order.outcome == 0):
            altOutcome = 1;
        
        balanceBefore = ERC20(IMarket(marketAddress).getShareToken(order.outcome)).balance(this);
        ITrade(AUGUR_TRADING_CONTRACT).publicFillBestOrder(order.direction, order.marketAddress, order.outcome, order,amount, order.price, 0, 1, false);
        balanceAfter = ERC20(IMarket(marketAddress).getShareToken(order.outcome)).balance(this);
        receivedMakerTokenAmount = balanceBefore - balanceAfter;

        require(
            ERC20(IMarket(marketAddress).getShareToken(order.outcome)) == makerToken,
            "Maker token isn't the outcome share we're buying"
        );

        ensureAllowance(
            makerToken,
            receiver,
            receivedMakerTokenAmount
        );

        return receivedMakerTokenAmount;
    }

    /**
     * Get amount of takerToken required to buy a certain amount of makerToken for a given trade.
     * Should match the takerToken amount used in exchangeForAmount. If the order cannot provide
     * exactly desiredMakerToken, then it must return the price to buy the minimum amount greater
     * than desiredMakerToken
     *
     * @param  makerToken         Address of makerToken, the token to receive
     * @param  takerToken         Address of takerToken, the token to pay
     * @param  desiredMakerToken  Amount of makerToken requested
     * @param  orderData          Arbitrary bytes data for any information to pass to the exchange
     * @return                    Amount of takerToken the needed to complete the transaction
     */
    function getExchangeCost(
        address /* makerToken */,
        address /* takerToken */,
        uint256 desiredMakerToken,
        bytes orderData
    )
        external
        view
        returns (uint256)
    {
        Order memory order = parseOrder(orderData);
        return MathHelpers.getPartialAmountRoundedUp(
            order.amount * order.price, /* taker token amount */
            order.amount, /* maker token amount */
            desiredMakerToken
        );
    }


    // ============ Public Functions ============

    /**
     * Get the maxmimum amount of makerToken for some order
     *
     * @param  makerToken           Address of makerToken, the token to receive
     * @param  takerToken           Address of takerToken, the token to pay
     * @param  orderData            Arbitrary bytes data for any information to pass to the exchange
     * @return                      Maximum amount of makerToken
     */
    function getMaxMakerAmount(
        address makerToken,
        address takerToken,
        bytes orderData
    )
        external
        view
        returns (uint256)
    {
        Order memory order = parseOrder(orderData);
        uint256 makerAmount = order.amount;
        return makerAmount;
    }

    // ============ Private Functions ============

    function ensureAllowance(
        address token,
        address spender,
        uint256 requiredAmount
    )
        private
    {
        if (token.allowance(address(this), spender) >= requiredAmount) {
            return;
        }

        token.approve(
            spender,
            MathHelpers.maxUint256()
        );
    }

    /**
     * Accepts a byte array with each variable padded to 32 bytes
     */
    function parseOrder(
        bytes orderData
    )
        private
        pure
        returns (Order memory)
    {
        Order memory order;

        /**
         * Total: 384 bytes
         * mstore stores 32 bytes at a time, so go in increments of 32 bytes
         *
         * NOTE: The first 32 bytes in an array stores the length, so we start reading from 32
         */
        /* solium-disable-next-line security/no-inline-assembly */
        assembly {
            mstore(order,           mload(add(orderData, 32)))  // marketAddress
            mstore(add(order, 32),  mload(add(orderData, 64)))  // taker
            mstore(add(order, 64),  mload(add(orderData, 96)))  // amount
            mstore(add(order, 96),  mload(add(orderData, 128))) // price
            mstore(add(order, 128), mload(add(orderData, 160))) // direction
            mstore(add(order, 160), mload(add(orderData, 192))) // outcome
        }

        return order;
    }
}