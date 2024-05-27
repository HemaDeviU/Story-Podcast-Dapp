// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;
import { IPAssetRegistry } from "lib/protocol-core-v1/contracts/registries/IPAssetRegistry.sol";
import { LicensingModule } from "lib/protocol-core-v1/contracts/modules/licensing/LicensingModule.sol";
import { PILicenseTemplate } from "lib/protocol-core-v1/contracts/modules/licensing/PILicenseTemplate.sol";
import {RoyaltyModule} from "lib/protocol-core-v1/contracts/modules/royalty/RoyaltyModule.sol";
import {IPAccountRegistry} from "lib/protocol-core-v1/contracts/registries/IPAccountRegistry.sol";
import {IIPAccount} from "lib/protocol-core-v1/contracts/interfaces/IIPAccount.sol";
import {RoyaltyPolicyLAP} from "lib/protocol-core-v1/contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import {IpRoyaltyVault} from "lib/protocol-core-v1/contracts/modules/royalty/policies/IpRoyaltyVault.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import { StoryPod } from "./StoryPod.sol";


interface IERC20 {
    function mint(address to, uint256 amount) external;
    function transfer(address recipient, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external view returns (bool);
}

/// @notice Register content as an NFT with an IP Account.License,remix and enjoy shared revenue from your creation.
contract PodcastCore is IERC721Receiver {
    IPAssetRegistry public immutable IP_ASSET_REGISTRY;
    IPAccountRegistry public immutable IP_ACCOUNT_REGISTRY;
    LicensingModule public immutable LICENSING_MODULE;
    PILicenseTemplate public immutable PIL_TEMPLATE;
    RoyaltyModule public immutable ROYALTY_MODULE;
    RoyaltyPolicyLAP public immutable ROYALTYPOLICYLAP;
    IpRoyaltyVault public immutable IPROYALTYVAULT;
     IERC20 public immutable TIP_TOKEN;
    StoryPod public immutable STORYPOD_NFT;
    address immutable tiptoken = 0xB132A6B7AE652c974EE1557A3521D53d18F6739f;
    

   struct IpDetails {
        uint256 tokenId;
        address ipId;
    }

    mapping (address => string) internal userNames;
    mapping (address => IpDetails) internal ipIdDetails;
    IpDetails[] internal ipDetails;

    event remixRequest(address indexed ipOwner, uint256 requestedLtAmount, address indexed recipient, string message);
    event remixPermissionGranted(address indexed ipId, uint256 ltAmount, address indexed recipient, string message);

    constructor(address ipAssetRegistry,address licensingModule, address pilTemplate, address royaltymodule, address iproyaltyvault, address royaltypolicylap) {
        IP_ASSET_REGISTRY = IPAssetRegistry(ipAssetRegistry);
       LICENSING_MODULE = LicensingModule(licensingModule);
       ROYALTY_MODULE = RoyaltyModule(royaltymodule);
        PIL_TEMPLATE = PILicenseTemplate(pilTemplate);
        IPROYALTYVAULT = IpRoyaltyVault(iproyaltyvault);
      ROYALTYPOLICYLAP = RoyaltyPolicyLAP(royaltypolicylap);
       TIP_TOKEN = IERC20(tiptoken);
        STORYPOD_NFT = new StoryPod(address(this));
    }

    /// @notice Mint an IP NFT, register it as an IP Account and attach license terms via Story Protocol core.
    /// @param uri of the episode from ipfs
    /// @return ipId The address of the IP Account
    /// @return tokenId The token ID of the IP NFT

    function registerandLicenseforUniqueIP(string memory uri, uint256 ltAmount,address ltRecipient) external returns (address ipId, uint256 tokenId, uint256 startLicenseTokenId) {
        tokenId = STORYPOD_NFT.safeMint(address(this), uri);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(STORYPOD_NFT), tokenId);
        //commercial license with remix royalty, so 3
        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), 3);
        STORYPOD_NFT.transferFrom(address(this), msg.sender, tokenId);
         startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: 3,
            amount: ltAmount,
            receiver: ltRecipient,
            royaltyContext: "" 
        });
        emit remixPermissionGranted(ipId, ltAmount, ltRecipient, message);
        ipDetails.push(IpDetails(
            tokenId,
            ipId
        ));
        ipIdDetails[ipId] = IpDetails(
            tokenId,
            ipId
        );
    }
    
    

    function requestRemixFromIPOwner(address ipId, uint256 ltAmount, string memory message) external {
        emit remixRequest(owner(ipIdDetails[ipId].tokenId), ltAmount, msg.sender, message);
    }

    ///@notice Remix IP :Register a derived episode IP NFT and mint License Tokens


    function registerAndMintTokenForRemixIP(
        uint256 ltAmount,
        address ltRecipient,string memory uri
    ) external returns (address ipId, uint256 tokenId, uint256 startLicenseTokenId) {
        
        address current = address(this);
        tokenId =  STORYPOD_NFT.safeMint(current,uri);
        ipId = IP_ASSET_REGISTRY.register(block.chainid, address(STORYPOD_NFT), tokenId);

        LICENSING_MODULE.attachLicenseTerms(ipId, address(PIL_TEMPLATE), 3);

        startLicenseTokenId = LICENSING_MODULE.mintLicenseTokens({
            licensorIpId: ipId,
            licenseTemplate: address(PIL_TEMPLATE),
            licenseTermsId: 3,
            amount: ltAmount,
            receiver: ltRecipient,
            royaltyContext: "" 
        });
         STORYPOD_NFT.transferFrom(address(this), msg.sender, tokenId);
         ipDetails.push(IpDetails(
            tokenId,
            ipId
        ));
        ipIdDetails[ipId] = IpDetails(
            tokenId,
            ipId
        );
    }



    //---Royalty----//
  
     function mintTipToken(address to, uint256 amount) external {
        TIP_TOKEN.mint(to, amount);
    }

    function tipEpisode(address ipId, uint256 amount) external payable {
        require(amount > 0, "Please tip more than zero");
        require(TIP_TOKEN.approve(address(this), amount), "Token approval failed");
        require(TIP_TOKEN.transferFrom(msg.sender, address(this), amount), "Token transfer failed");
        require(TIP_TOKEN.approve(address(ROYALTY_MODULE), amount), "Token approval failed");
        ROYALTY_MODULE.payRoyaltyOnBehalf(ipId,
         address(0),//user doesn't have ipid
         tiptoken,
         amount);
    }

    function collectFirstRoyalty(address ipId) external payable
    {
        (, address ipVaultAddress, , ,) = ROYALTYPOLICYLAP.getRoyaltyData(ipId);
        IpRoyaltyVault vault = IpRoyaltyVault(ipVaultAddress);
        vault.collectRoyaltyTokens(ipId);
    }


    function withdrawEarnings(address ipId, address tokenaddress) external payable{
       uint256 snapshotid = IPROYALTYVAULT.snapshot();
       uint256[] memory snapshot = new uint256[](1);
       snapshot[0] = snapshotid;
       IPROYALTYVAULT.claimRevenueBySnapshotBatch(snapshot,tokenaddress);
    }

    function registerUser(string memory _userName) external {
        userNames[msg.sender] = _userName;
    }

    function getUserName() public view returns (string memory) {
        string memory userName = userNames[msg.sender];
        require(bytes(userName).length > 0, "Username is not set");
        return userName;
    }
    function getIpDetails() public view returns (IpDetails[] memory) {
        return ipDetails;
    }
   
    function owner(uint256 tokenId) public view returns (address) {
        return STORYPOD_NFT.ownerOf(tokenId);
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        return STORYPOD_NFT.tokenURI(tokenId);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes memory data
    ) external override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    }

