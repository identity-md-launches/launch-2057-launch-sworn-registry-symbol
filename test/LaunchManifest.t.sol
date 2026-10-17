// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {Registry} from "../src/Registry.sol";
import {Renderer} from "../src/Renderer.sol";
import {Composer} from "../src/Composer.sol";

/// @notice The Sepolia launch: Renderer, Composer, then Registry with the brief's exact eight arguments,
///         on the launch checks' empty chain (constructor floor), with no owner role anywhere.
contract LaunchManifestTest is Test {
    address internal constant CURATOR = 0x0919ba50b206C3F31D516De818b1fBc7dA21653D;
    address internal constant IDMD = 0x2C3013c90a1Bb65573aae9a7C64fafB82697E4e4;
    address internal constant IMD = 0x44a1Cd38474FB1748400E7DEb5F8D786ccE3F89A;
    address internal constant INTAKE = 0xa43e6F75ee006411F79Ac1C84120606C2330DE82;
    address internal constant ATTESTER = 0x5598Aa9146215Bc13eb26f2c692Ad1461Fd32982;
    address internal constant BURN_EXECUTOR = 0x097A19e0f021BBA5072701132625ad2401043A2E;

    function test_launchOrderAndArgumentsDeployOnEmptyChain() public {
        vm.chainId(11155111);
        Renderer renderer = new Renderer();
        Composer composer = new Composer();
        Registry r =
            new Registry(CURATOR, IDMD, IMD, INTAKE, ATTESTER, address(renderer), address(composer), BURN_EXECUTOR);
        assertEq(address(r.curator()), CURATOR);
        assertEq(address(r.idmd()), IDMD);
        assertEq(address(r.imd()), IMD);
        assertEq(address(r.intake()), INTAKE);
        assertEq(r.attester(), ATTESTER);
        assertEq(address(r.renderer()), address(renderer));
        assertEq(address(r.composer()), address(composer));
        assertEq(address(r.burnExecutor()), BURN_EXECUTOR);
        assertEq(r.symbol(), "SWORN");
        assertEq(r.name(), "Sworn");
    }
}
