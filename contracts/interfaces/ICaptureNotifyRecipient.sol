// SPDX-License-Identifier: GPL
pragma solidity 0.7.4;

interface ICaptureNotifyRecipient {
    /**
     * @notice Value capture handler.
     */
    function onValueCaptured(uint256 totalCapturedUSD, uint256 lastCapturedBlock) external;
}
