// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../src/Registry.sol";
import {Renderer} from "../src/Renderer.sol";
import {Composer} from "../src/Composer.sol";
import {MockCurator, MockIDMD, MockIMD, MockIntake} from "./mocks/Mocks.sol";

/// @notice The Sepolia rehearsal's exact constructor arguments: the empty-chain floor, every zero
///         rejection, each dependency check, and the V1 executor stand-in whose preview reverts.
contract SepoliaLaunchArgsTest is Test {
    address internal constant CURATOR = 0x0919ba50b206C3F31D516De818b1fBc7dA21653D;
    address internal constant IDMD = 0x2C3013c90a1Bb65573aae9a7C64fafB82697E4e4;
    address internal constant IMD = 0x44a1Cd38474FB1748400E7DEb5F8D786ccE3F89A;
    address internal constant INTAKE = 0xa43e6F75ee006411F79Ac1C84120606C2330DE82;
    address internal constant ATTESTER = 0x5598Aa9146215Bc13eb26f2c692Ad1461Fd32982;
    address internal constant EXECUTOR = 0x097A19e0f021BBA5072701132625ad2401043A2E;

    Renderer internal renderer;
    Composer internal composer;

    function setUp() public {
        vm.chainId(11155111);
        vm.warp(1_792_143_071);
        renderer = new Renderer();
        composer = new Composer();
    }

    function _args() internal view returns (address[8] memory a) {
        a = [CURATOR, IDMD, IMD, INTAKE, ATTESTER, address(renderer), address(composer), EXECUTOR];
    }

    function _deploy(address[8] memory a) internal returns (Registry) {
        return new Registry(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]);
    }

    function _liveDeps() internal {
        deployCodeTo("Mocks.sol:MockCurator", CURATOR);
        deployCodeTo("Mocks.sol:MockIDMD", IDMD);
        deployCodeTo("Mocks.sol:MockIMD", IMD);
        deployCodeTo("Mocks.sol:MockIntake", abi.encode(IMD), INTAKE);
        // V1 stand-in: code present, previewBridge() reverts (PUSH1 0 PUSH1 0 REVERT).
        vm.etch(EXECUTOR, hex"60006000fd");
    }

    function test_emptyChainFloorAcceptsTheExactArguments() public {
        Registry r = _deploy(_args());
        assertEq(r.name(), "Sworn");
        assertEq(r.symbol(), "SWORN");
        assertEq(address(r.curator()), CURATOR);
        assertEq(address(r.idmd()), IDMD);
        assertEq(address(r.imd()), IMD);
        assertEq(address(r.intake()), INTAKE);
        assertEq(r.attester(), ATTESTER);
        assertEq(address(r.renderer()), address(renderer));
        assertEq(address(r.composer()), address(composer));
        assertEq(address(r.burnExecutor()), EXECUTOR);
        assertEq(r.nextSpecId(), 10001);
    }

    /// forge-config: default.fuzz.runs = 256
    function testFuzz_anyZeroAmongTheSevenRequiredRevertsZeroAddress(uint8 i, bool live) public {
        if (live) _liveDeps();
        address[8] memory a = _args();
        a[bound(i, 0, 6)] = address(0);
        vm.expectRevert(Registry.ZeroAddress.selector);
        _deploy(a);
    }

    function test_liveDependenciesAcceptTheExactArguments() public {
        _liveDeps();
        Registry r = _deploy(_args());
        assertEq(address(r.burnExecutor()), EXECUTOR);
    }

    function test_partialCodeLeavesTheFloorAndChecksIdmd() public {
        deployCodeTo("Mocks.sol:MockCurator", CURATOR);
        vm.expectRevert(Registry.DependencyHasNoCode.selector);
        _deploy(_args());
    }

    function test_zeroIntakePriceReverts() public {
        _liveDeps();
        MockIntake(INTAKE).setPrice(0);
        vm.expectRevert(bytes("Intake price"));
        _deploy(_args());
    }

    function test_executorWithoutCodeRevertsOffTheFloor() public {
        _liveDeps();
        vm.etch(EXECUTOR, "");
        vm.expectRevert(Registry.ExecutorHasNoCode.selector);
        _deploy(_args());
    }

    function test_v1ExecutorSkipsWithCodeOneAndRefundsTheClaimant() public {
        _liveDeps();
        Registry r = _deploy(_args());
        address alice = address(0xA11CE);
        MockCurator(CURATOR).set(alice, 1, true, 1, 1, 1);
        MockIMD(IMD).mint(address(r), 10 ether);
        vm.deal(alice, 1 ether);
        uint256 price = MockIntake(INTAKE).priceOf(r.ACTION(), IMD);

        vm.expectEmit(true, false, false, true, address(r));
        emit Registry.BurnSkipped(alice, 1);
        vm.prank(alice);
        r.claimSponsored{value: 0.01 ether}(701);

        assertEq(alice.balance, 1 ether, "ETH refunded");
        assertEq(address(r).balance, 0);
        assertTrue(r.pendingOf(alice, 701) != 0, "request still made");
        assertEq(r.pool(), 10 ether - price, "price spent regardless");
        assertEq(MockIMD(IMD).balanceOf(INTAKE), price);
    }

    function test_v1ExecutorSecondSponsoredClaimSameDayStillHitsDailyLimit() public {
        _liveDeps();
        Registry r = _deploy(_args());
        address alice = address(0xA11CE);
        MockCurator(CURATOR).set(alice, 1, true, 1, 1, 1);
        MockIMD(IMD).mint(address(r), 10 ether);
        vm.prank(alice);
        r.claimSponsored(701);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Registry.PoolDailyLimit.selector, alice));
        r.claimSponsored(801);
    }
}
