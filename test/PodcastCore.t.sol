// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import { Test } from "forge-std/Test.sol";
import { IPAssetRegistry } from "lib/protocol-core-v1/contracts/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "lib/protocol-core-v1/contracts/registries/LicenseRegistry.sol";
import { PILicenseTemplate } from "lib/protocol-core-v1/contracts/modules/licensing/PILicenseTemplate.sol";
import  {PodcastCore} from "../src/PodcastCore.sol";
import { StoryPod } from "../src/StoryPod.sol";

contract PodcastCoreTest is Test {
    address internal alice = address(0xa11ce);

    // Protocol Core v1 addresses
    // (see https://docs.storyprotocol.xyz/docs/deployed-smart-contracts)
    address internal ipAssetRegistryAddr = 0xd43fE0d865cb5C26b1351d3eAf2E3064BE3276F6;
    address internal licensingModuleAddr = 0xe89b0EaA8a0949738efA80bB531a165FB3456CBe;
    address internal licenseRegistryAddr = 0x4f4b1bf7135C7ff1462826CCA81B048Ed19562ed;
    address internal pilTemplateAddr = 0x260B6CB6284c89dbE660c0004233f7bB99B5edE7;

    IPAssetRegistry public ipAssetRegistry;
    LicenseRegistry public licenseRegistry;

    PodcastCore public podcastcore;
    StoryPod public storyPod;

    function setUp() public {
        ipAssetRegistry = IPAssetRegistry(ipAssetRegistryAddr);
        licenseRegistry = LicenseRegistry(licenseRegistryAddr);
        podcastcore = new PodcastCore(ipAssetRegistryAddr, licensingModuleAddr, pilTemplateAddr);
        storyPod = StoryPod(podcastcore.STORYPOD_NFT());

        vm.label(address(ipAssetRegistryAddr), "IPAssetRegistry");
        vm.label(address(licensingModuleAddr), "LicensingModule");
        vm.label(address(licenseRegistryAddr), "LicenseRegistry");
        vm.label(address(pilTemplateAddr), "PILicenseTemplate");
        vm.label(address(storyPod), "StoryPod");
        vm.label(address(0x000000006551c19487814612e58FE06813775758), "ERC6551Registry");
    }

    function test_attachLicenseTerms() public {
        uint256 expectedTokenId = storyPod.nextTokenId();
        address expectedIpId = ipAssetRegistry.ipId(block.chainid, address(storyPod), expectedTokenId);

        address expectedLicenseTemplate = pilTemplateAddr;
        uint256 expectedLicenseTermsId = 3;

        vm.prank(alice);
        (address ipId, uint256 tokenId) = podcastcore.attachLicenseTerms();

        assertEq(ipId, expectedIpId);
        assertEq(tokenId, expectedTokenId);
        assertEq(storyPod.ownerOf(tokenId), alice);

        assertTrue(licenseRegistry.hasIpAttachedLicenseTerms(ipId, expectedLicenseTemplate, expectedLicenseTermsId));
        assertEq(licenseRegistry.getAttachedLicenseTermsCount(ipId), 3);

        (address licenseTemplate, uint256 licenseTermsId) = licenseRegistry.getAttachedLicenseTerms({
            ipId: ipId,
            index: 0
        });
        assertEq(licenseTemplate, expectedLicenseTemplate);
        assertEq(licenseTermsId, expectedLicenseTermsId);
    }
}
