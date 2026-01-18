// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC20Token} from "./erc20-token.sol";
import {ERC20TokenV2} from "./erc20-token-v2.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

contract ERC20TokenV2Test is Test {
    ERC20Token implementationV1;
    ERC20TokenV2 implementationV2;
    ERC20Token tokenV1;
    ERC20TokenV2 tokenV2;
    ERC1967Proxy proxy;
    
    address owner;
    address user;
    
    uint256 constant INITIAL_SUPPLY = 1000 * 10**18;
    string constant TOKEN_NAME = "TestToken";
    string constant TOKEN_SYMBOL = "TT";
    uint8 constant TOKEN_DECIMALS = 18;

    // Функция setUp выполняется перед каждым тестом и подготавливает окружение.
    function setUp() public {
        owner = address(this);
        user = address(0x1);
        
        implementationV1 = new ERC20Token();
        
        bytes memory initData = abi.encodeWithSelector(
            ERC20Token.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS
        );
        
        proxy = new ERC1967Proxy(address(implementationV1), initData);
        tokenV1 = ERC20Token(address(proxy));
    }

    function test_UpgradeToV2() public {
        implementationV2 = new ERC20TokenV2();
        
        // Обновим реализацию до версии 2
        tokenV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(ERC20TokenV2.initializeV2.selector)
        );        
        tokenV2 = ERC20TokenV2(address(proxy));
        
        string memory version = tokenV2.version();
        require(keccak256(bytes(version)) == keccak256(bytes("version 2")), "Version should be 2");
        
        require(tokenV2.totalSupply() == INITIAL_SUPPLY, "Total supply should be preserved");
        require(tokenV2.balanceOf(owner) == INITIAL_SUPPLY, "Balance should be preserved");
    }

    function test_Burn() public {
        implementationV2 = new ERC20TokenV2();

        // Обновим реализацию до версии 2
        tokenV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(ERC20TokenV2.initializeV2.selector)
        );
        tokenV2 = ERC20TokenV2(address(proxy));
        
        uint256 burnAmount = 100 * 10**18;
        uint256 balanceBefore = tokenV2.balanceOf(owner);
        uint256 supplyBefore = tokenV2.totalSupply();
        
        tokenV2.burn(burnAmount);
        
        require(tokenV2.balanceOf(owner) == balanceBefore - burnAmount, "Balance should decrease");
        require(tokenV2.totalSupply() == supplyBefore - burnAmount, "Total supply should decrease");
    }

    function test_BurnFailsOnInsufficientBalance() public {
        implementationV2 = new ERC20TokenV2();
        tokenV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(ERC20TokenV2.initializeV2.selector)
        );
        tokenV2 = ERC20TokenV2(address(proxy));
        
        uint256 burnAmount = tokenV2.balanceOf(user) + 1;
        
        vm.prank(user);
        vm.expectRevert();
        tokenV2.burn(burnAmount);
    }

    // Проверяем, что при обновлении реализации сохраняется состояние
    function test_UpgradePreservesState() public {
        // Минтим токены перед обновлением
        uint256 mintAmount = 500 * 10**18;
        tokenV1.mint(user, mintAmount);
        
        // Обновим реализацию до версии 2
        implementationV2 = new ERC20TokenV2();
        tokenV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(ERC20TokenV2.initializeV2.selector)
        );
        tokenV2 = ERC20TokenV2(address(proxy));
        
        // Проверяем, что состояние сохранилось
        require(
            tokenV2.totalSupply() == INITIAL_SUPPLY + mintAmount, 
            "Total supply should be preserved"
        );
        require(tokenV2.balanceOf(owner) == INITIAL_SUPPLY, "Owner balance should be preserved");
        require(tokenV2.balanceOf(user) == mintAmount, "User balance should be preserved");
    }

    function test_V1FunctionsStillWorkAfterUpgrade() public {
        // Обновим реализацию до версии 2
        implementationV2 = new ERC20TokenV2();
        tokenV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(ERC20TokenV2.initializeV2.selector)
        );
        tokenV2 = ERC20TokenV2(address(proxy));
        
        // Проверяем, что функции V1 работают после обновления
        uint256 amount = 100 * 10**18;
        tokenV2.mint(user, amount);
        require(tokenV2.balanceOf(user) == amount, "Mint should work");
        
        // Переведем токены от owner'а
        tokenV2.transfer(user, amount);
        require(tokenV2.balanceOf(user) == amount * 2, "Transfer should work");
    }

    function test_UpgradeFailsWithoutAdminRole() public {
        implementationV2 = new ERC20TokenV2();
        
        vm.prank(user);
        vm.expectRevert();
        tokenV1.upgradeToAndCall(
            address(implementationV2),
            abi.encodeWithSelector(ERC20TokenV2.initializeV2.selector)
        );
    }
}
