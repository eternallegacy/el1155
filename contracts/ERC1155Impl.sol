// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC1155Impl is ERC1155, Ownable {
    using SafeERC20 for IERC20;
    address internal signer;
    uint256 internal curId;
    mapping(uint256 => bool) internal nonces;

    struct NftInfo {
        uint256 id;
        string URI;
        uint256 totalLimit;
        uint256 enableBlockHeight;
        address chargeToken;
        uint256 price;
        address receiver;
        uint256 balanceLimit;
    }

    mapping(uint256 => NftInfo) public nftInfos;
    mapping(uint256 => uint256) public mintedNum;

    string public constant name = "Eternal Legacy Pack";
    string public constant version = "1.0";
    bytes32 public DOMAIN_SEPARATOR;

    modifier onlyNonce(uint256 nonce) {
        require(nonces[nonce] == false, "NftTemplate: duplicate nonce");
        nonces[nonce] = true;
        _;
    }

    event SetSigner(address oldSigner, address newSigner);
    event Register(
        uint256 indexed id,
        string URI,
        uint256 totalLimit,
        uint256 enableBlockHeight,
        address chargeToken,
        uint256 price,
        address receiver,
        uint256 balanceLimit
    );
    event UpdatePrice(
        uint256 indexed id,
        address chargeToken,
        uint256 price,
        address receiver
    );
    event Update(
        uint256 id,
        string URI,
        uint256 totalLimit,
        uint256 balanceLimit,
        uint256 enableBlockHeight
    );

    constructor(string memory uri_) ERC1155(uri_) Ownable() {
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

    function getSigner() public view returns (address) {
        return signer;
    }

    function setSigner(address newSigner) public onlyOwner {
        address old = signer;
        signer = newSigner;
        emit SetSigner(old, newSigner);
    }

    function register(
        uint256 id,
        string calldata URI,
        uint256 totalLimit,
        uint256 enableBlockHeight,
        address chargeToken,
        uint256 price,
        address receiver,
        uint256 balanceLimit
    ) public onlyOwner {
        require(
            enableBlockHeight >= block.number,
            "ERC1155Impl: invalid enableBlockHeight"
        );
        require(nftInfos[id].enableBlockHeight == 0, "ERC1155Impl: existed id");
        nftInfos[id] = NftInfo(
            id,
            URI,
            totalLimit,
            enableBlockHeight,
            chargeToken,
            price,
            receiver,
            balanceLimit
        );
        emit Register(
            id,
            URI,
            totalLimit,
            enableBlockHeight,
            chargeToken,
            price,
            receiver,
            balanceLimit
        );
    }

    function getInfo(uint256 id) public view returns (NftInfo memory) {
        return nftInfos[id];
    }

    function getStats(uint256 id) public view returns (uint256) {
        return mintedNum[id];
    }

    function updatePrice(
        uint256 id,
        address chargeToken,
        uint256 price,
        address receiver
    ) public onlyOwner {
        NftInfo storage nftInfo = nftInfos[id];
        require(nftInfo.enableBlockHeight != 0, "ERC1155Impl: invalid id");
        nftInfo.chargeToken = chargeToken;
        nftInfo.price = price;
        nftInfo.receiver = receiver;
        emit UpdatePrice(id, chargeToken, price, receiver);
    }

    function update(
        uint256 id,
        string calldata URI,
        uint256 totalLimit,
        uint256 balanceLimit,
        uint256 enableBlockHeight
    ) public onlyOwner {
        NftInfo storage nftInfo = nftInfos[id];
        require(nftInfo.enableBlockHeight != 0, "ERC1155Impl: invalid id");
        require(
            totalLimit >= mintedNum[id],
            "ERC1155Impl: minted amount exceed limit"
        );
        nftInfo.URI = URI;
        nftInfo.totalLimit = totalLimit;
        nftInfo.balanceLimit = balanceLimit;
        nftInfo.enableBlockHeight = enableBlockHeight;
        emit Update(id, URI, totalLimit, balanceLimit, enableBlockHeight);
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        return nftInfos[tokenId].URI;
    }

    function mint(uint256 id, uint256 amount) public payable {
        NftInfo storage nftInfo = nftInfos[id];
        require(
            block.number >= nftInfo.enableBlockHeight,
            "ERC1155Impl: enableBlockHeight not reached"
        );
        require(
            mintedNum[id] + amount <= nftInfo.totalLimit,
            "ERC1155Impl: exceed limit"
        );
        require(
            super.balanceOf(msg.sender, id) + amount <= nftInfo.balanceLimit,
            "ERC1155Impl: balance exceed limit"
        );
        if ((amount * nftInfo.price) > 0) {
            if (isNativeToken(nftInfo.chargeToken)) {
                require(msg.value >= (amount * nftInfo.price), "ERC1155Impl: msg.value not enough");
                payable(nftInfo.receiver).transfer(msg.value);
            } else {
                IERC20(nftInfo.chargeToken).safeTransferFrom(
                    msg.sender,
                    nftInfo.receiver,
                    amount * nftInfo.price
                );
            }
        }
        _mint(msg.sender, id, amount, bytes(nftInfo.URI));
        mintedNum[id] += amount;
    }

    function rewardMint(address to, uint256 id, uint256 amount) public {
        NftInfo storage nftInfo = nftInfos[id];
        require(msg.sender == nftInfo.receiver, "ERC1155Impl: no privilege");
        require(
            mintedNum[id] + amount <= nftInfo.totalLimit,
            "ERC1155Impl: exceed limit"
        );
        require(
            super.balanceOf(to, id) + amount <= nftInfo.balanceLimit,
            "ERC1155Impl: balance exceed limit"
        );
        _mint(to, id, amount, bytes(nftInfo.URI));
        mintedNum[id] += amount;
    }

    function burn(uint256 id, uint256 amount) public {
        require(
            super.balanceOf(msg.sender, id) >= amount,
            "ERC1155Impl: exceed balance"
        );
        _burn(msg.sender, id, amount);
    }

    function burnWithSig(
        uint256 id,
        uint256 amount,
        uint256 nonce,
        bytes calldata sig
    ) public onlyNonce(nonce) {
        require(
            super.balanceOf(msg.sender, id) >= amount,
            "ERC1155Impl: exceed balance"
        );
        bytes32 hash = hashBurnParams(id, amount, msg.sender, nonce);
        require(_checkInSigs(hash, sig), "NftTemplate: invalid signature");

        _burn(msg.sender, id, amount);
    }

    function hashBurnParams(
        uint256 id,
        uint256 amount,
        address user,
        uint256 nonce
    ) public view returns (bytes32) {
        //ERC-712
        return
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    DOMAIN_SEPARATOR,
                    keccak256(
                        abi.encode(
                            keccak256(
                                "burnParams(uint256 id,uint256 amount,address user,uint256 nonce)"
                            ),
                            id,
                            amount,
                            user,
                            nonce
                        )
                    )
                )
            );
    }

    function _checkInSigs(
        bytes32 message,
        bytes calldata sigs
    ) internal view returns (bool) {
        (uint8 v, bytes32 r, bytes32 s) = _splitSignature(sigs);
        address signerA = ecrecover(message, v, r, s);
        return signerA == signer;
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

    function isNativeToken(address token) internal pure returns (bool) {
        return token == address(0);
    }
}
