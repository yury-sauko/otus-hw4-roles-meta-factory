// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test} from "forge-std/Test.sol";

import {ERC20Token} from "./erc20-token.sol";


contract ERC20TokenTest is Test {
    ERC20Token implementation;
    ERC20Token token;
    ERC1967Proxy proxy;    
    
    address owner;
    address user;
    address spender;
    
    uint256 constant INITIAL_SUPPLY = 1000 * 10**18;
    string constant TOKEN_NAME = "TestToken";
    string constant TOKEN_SYMBOL = "TT";
    uint8 constant TOKEN_DECIMALS = 18;

    // Стандартный приватный ключ первого аккаунта Foundry/Anvil для тестирования подписей
    uint256 constant OWNER_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    
    // Константы для EIP-712 typehash
    bytes32 constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 constant TRANSFER_TYPEHASH = keccak256("Transfer(address from,address to,uint256 amount,uint256 nonce,uint256 deadline)");
    bytes32 constant APPROVE_TYPEHASH = keccak256("Approve(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)");

    // Функция setUp выполняется перед каждым тестом и подготавливает окружение.
    function setUp() public {
        owner = address(this);
        user = address(0x1);
        spender = address(0x2);
        
        implementation = new ERC20Token();
        
        // Сформируем calldata для вызова функции initialize, так как
        // возможность инициализации контракта напрямую отключена, только через прокси.
        bytes memory initData = abi.encodeWithSelector(
            ERC20Token.initialize.selector,
            TOKEN_NAME,
            TOKEN_SYMBOL,
            TOKEN_DECIMALS
        );
        
        // Инициализация контракта имплементации происходит здесь, при деплое прокси.
        proxy = new ERC1967Proxy(address(implementation), initData);
        // Приводим адрес прокси к типу ERC20Token, чтобы вызывать методы контракта токена.
        token = ERC20Token(address(proxy));
    }

    function test_Initialization() public view {
        require(
            keccak256(bytes(token.name())) == keccak256(bytes(TOKEN_NAME)), 
            "Name should match"
        );
        require(
            keccak256(bytes(token.symbol())) == keccak256(bytes(TOKEN_SYMBOL)), 
            "Symbol should match"
        );
        require(token.decimals() == TOKEN_DECIMALS, "Decimals should match");
        require(token.totalSupply() == INITIAL_SUPPLY, "Total supply should be initial amount");
        require(token.balanceOf(owner) == INITIAL_SUPPLY, "Owner should have initial supply");
    }

    // Ожидаем revert при попытке повторной инициализации контракта имплементации, 
    // так как инициализация уже выполнена в setUp.
    function test_InitializationFailsOnSecondCall() public {
        vm.expectRevert();
        token.initialize(TOKEN_NAME, TOKEN_SYMBOL, TOKEN_DECIMALS);
    }

    // Функцию hasRole имплементация наследует от абстрактного контракта
    // AccessControlUpgradeable из OpenZeppelin.
    function test_OwnerHasAdminRole() public view {
        require(token.hasRole(token.DEFAULT_ADMIN_ROLE(), owner), "Owner should have admin role");
    }

    function test_OwnerHasMinterRole() public view {
        require(token.hasRole(token.MINTER_ROLE(), owner), "Owner should have minter role");
    }

    function test_Mint() public {
        uint256 amount = 100 * 10**18;
        token.mint(user, amount);
        
        require(token.balanceOf(user) == amount, "User should receive minted tokens");
        require(token.totalSupply() == INITIAL_SUPPLY + amount, "Total supply should increase");
    }

    function test_MintFailsWithoutMinterRole() public {
        vm.prank(user);
        vm.expectRevert();
        token.mint(user, 100 * 10**18);
    }

    function test_Transfer() public {
        uint256 amount = 100 * 10**18;
        token.transfer(user, amount);
        
        require(token.balanceOf(owner) == INITIAL_SUPPLY - amount, "Owner balance should decrease");
        require(token.balanceOf(user) == amount, "User balance should increase");
    }

    function test_TransferFailsOnInsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert();
        token.transfer(spender, 100 * 10**18);
    }

    function test_Approve() public {
        uint256 amount = 100 * 10**18;
        token.approve(spender, amount);
        
        require(token.allowance(owner, spender) == amount, "Allowance should be set");
    }

    function test_TransferFrom() public {
        uint256 amount = 100 * 10**18;
        token.approve(spender, amount);
        
        vm.prank(spender);
        token.transferFrom(owner, user, amount);
        
        require(token.balanceOf(user) == amount, "User should receive tokens");
        require(token.allowance(owner, spender) == 0, "Allowance should be decreased");
    }

    function test_TransferFromFailsOnInsufficientAllowance() public {
        token.approve(spender, 50 * 10**18);
        
        vm.prank(spender);
        vm.expectRevert();
        token.transferFrom(owner, user, 100 * 10**18);
    }

    function test_Permit() public {
        // Сгенерируем адрес из тестового приватного ключа
        address signer = vm.addr(OWNER_PRIVATE_KEY);
        
        token.mint(signer, INITIAL_SUPPLY);
        
        uint256 amount = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);
        
        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            signer,
            spender,
            amount,
            nonce,
            deadline
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PRIVATE_KEY, hash);
        
        token.permit(signer, spender, amount, deadline, v, r, s);
        
        require(token.allowance(signer, spender) == amount, "Allowance should be set via permit");
        require(token.nonces(signer) == nonce + 1, "Nonce should increment");
    }

    function test_PermitFailsOnExpiredDeadline() public {
        address signer = vm.addr(OWNER_PRIVATE_KEY);
        token.mint(signer, INITIAL_SUPPLY);
        
        uint256 amount = 100 * 10**18;
        uint256 deadline = block.timestamp - 1;
        uint256 nonce = token.nonces(signer);
        
        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            signer,
            spender,
            amount,
            nonce,
            deadline
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PRIVATE_KEY, hash);
        
        vm.expectRevert();
        token.permit(signer, spender, amount, deadline, v, r, s);
    }

    function test_MetaTransfer() public {
        address signer = vm.addr(OWNER_PRIVATE_KEY);
        token.mint(signer, INITIAL_SUPPLY);
        
        uint256 amount = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);
        
        bytes32 structHash = keccak256(abi.encode(
            TRANSFER_TYPEHASH,
            signer,
            user,
            amount,
            nonce,
            deadline
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PRIVATE_KEY, hash);

        bytes memory signature = abi.encodePacked(r, s, v);
        
        token.metaTransfer(signer, user, amount, deadline, signature);
        
        require(token.balanceOf(user) == amount, "User should receive tokens");
        require(token.nonces(signer) == nonce + 1, "Nonce should increment");
    }

    function test_MetaApprove() public {
        address signer = vm.addr(OWNER_PRIVATE_KEY);
        
        uint256 amount = 100 * 10**18;
        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(signer);
        
        bytes32 structHash = keccak256(abi.encode(
            APPROVE_TYPEHASH,
            signer,
            spender,
            amount,
            nonce,
            deadline
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(OWNER_PRIVATE_KEY, hash);

        bytes memory signature = abi.encodePacked(r, s, v);
        
        token.metaApprove(signer, spender, amount, deadline, signature);
        
        require(token.allowance(signer, spender) == amount, "Allowance should be set");
        require(token.nonces(signer) == nonce + 1, "Nonce should increment");
    }

    function test_Version() public view {
        string memory version = token.version();
        require(keccak256(bytes(version)) == keccak256(bytes("version 1")), "Version should be 1");
    }

    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256(bytes(TOKEN_NAME)),
            keccak256(bytes("1")),
            block.chainid,
            address(token)
        ));

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}
