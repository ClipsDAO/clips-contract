// SPDX-License-Identifier: MIT

pragma solidity >=0.4.22 <0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

import "./OnlyOnce.sol";
import "./InitializeOwnable.sol";
import "./ERC20NoConstructor.sol";

import "./interfaces/IInstantiate.sol";
import "./interfaces/ISwap.sol";
import "./interfaces/IID.sol";
import "./interfaces/IFeeRate.sol";

contract Platform is OnlyOnce, InitializeOwnable, ERC20NoConstructor {
    uint256 public availableAuctionId;
    uint256 public availableTemplateId;
    mapping(uint256 => address) public templates;
    mapping(uint256 => address) public auctions;
    mapping(uint256 => uint256) public auctionTemplate;

    modifier validAuctionId(uint256 id) {
        require(availableAuctionId == id, "invalid auction id");
        availableAuctionId += 1;
        _;
    }

    modifier validTemplateId(uint256 id) {
        require(templates[id] != address(0), "invalid template id");
        _;
    }

    function initialize(address owner, string calldata symbol) public onlyOnce {
        InitializeOwnable.initialize(owner);
        ERC20NoConstructor.initialize(symbol, symbol, 18);
    }

    function addTemplate(uint256 tid, address template) public onlyOwner {
        require(tid == availableTemplateId, "invalid template id");
        templates[tid] = template;
        availableTemplateId += 1;
    }

    function updateTemplate(uint256 tid, address template)
        public
        onlyOwner
        validTemplateId(tid)
    {
        templates[tid] = template;
    }

    /// instantiate a new instance of type `tid`
    /// @param tid should be a known template id
    /// @param aid should be the valid auction id
    /// @param initdata is the encoeded init data for template creation
    function instantiate(
        uint256 tid,
        uint256 aid,
        bytes calldata initdata
    ) public validTemplateId(tid) validAuctionId(aid) {
        address inst = IInstantiate(templates[tid]).instantiate(initdata);
        auctions[aid] = inst;
        auctionTemplate[aid] = tid;

        require(IID(inst).id() == aid, "inconsistent id");

        IERC20(ISwap(inst).token()).transferFrom(
            msg.sender,
            inst,
            ISwap(inst).supply()
        );
    }

    function extract(
        address _token,
        address payable _recv,
        uint256 _amount
    ) public onlyOwner {
        if (_token == address(0)) {
            _recv.transfer(_amount);
        } else {
            IERC20(_token).transfer(_recv, _amount);
        }
    }

    function setFeeRate(uint256 aid, uint256 _fee) public onlyOwner {
        address addr = auctions[aid];
        require(addr != address(0), "unknown aid");
        IFeeRate(addr).setFeeRate(_fee);
    }

    receive() external payable {}
}
