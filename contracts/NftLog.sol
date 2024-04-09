// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract NftLog is Ownable {
    address public signer;
    string public constant name = "NftLog";
    string public constant version = "1.0";
    bytes32 public DOMAIN_SEPARATOR;

    event LogMsg(address user, address signer, string log, uint256 height);
    event SetSigner(address oldSigner, address newSigner);

    constructor() Ownable(msg.sender) {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes(name)),
                keccak256(bytes(version)), //version
                block.chainid,
                address(this)
            )
        );
    }

    function setSigner(address newSigner) public onlyOwner {
        address old = signer;
        signer = newSigner;
        emit SetSigner(old, newSigner);
    }

    function logSig(
        string calldata log,
        uint256 nonce,
        bytes calldata sig
    ) public {
        bytes32 hash = hashMsg(msg.sender, log, nonce);
        require(_checkInSigs(hash, sig), "NftLog: invalid signature");
        emit LogMsg(msg.sender, signer, log, block.number);
    }

    function _checkInSigs(
        bytes32 message,
        bytes calldata sigs
    ) internal view returns (bool) {
        (uint8 v, bytes32 r, bytes32 s) = _splitSignature(sigs);
        address signerAddr = ecrecover(message, v, r, s);
        return signer == signerAddr;
    }

    function hashMsg(
        address user,
        string calldata log,
        uint256 nonce
    ) public view returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            keccak256(
                                "logSig(address user,string log,uint256 nonce)"
                            ),
                            user,
                            keccak256(bytes(log)),
                            nonce
                        )
                    )
                )
            );
    }

    // signature methods.
    function _splitSignature(
        bytes memory sig
    ) internal pure returns (uint8 v, bytes32 r, bytes32 s) {
        require(sig.length == 65);

        assembly {
            // first 32 bytes, after the length prefix.
            r := mload(add(sig, 32))
            // second 32 bytes.
            s := mload(add(sig, 64))
            // final byte (first byte of the next 32 bytes).
            v := byte(0, mload(add(sig, 96)))
        }

        return (v, r, s);
    }
}
