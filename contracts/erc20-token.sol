// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import { IERC20Errors } from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

/**
 * Урок 20, задачи по ДЗ:
 * 1. Создайте контракт с уровнями доступа.
 * Примененные в контракте механизмы контроля доступа:
 * - условные выражения с оператором revert для отклонения транзакций при несоблюдении условий;
 * - модификаторы видимости private, external;
 * - механизм ограничения доступа на основе ролей (RBAC) с использованием AccessControl 
 * из OpenZeppelin. Минимальный набор ролей, в обучающих целях;
 * 
 * 2. Внедрите мета-транзакции в контракт.
 * ...
 */

contract ERC20Token is IERC20, IERC20Metadata, IERC20Errors, AccessControl {
    // Переменные состояния расположим в правильном порядке
    // для оптимизации упаковки в storage

    // константа в storage не упаковывается
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    // decimals занимает 1 байт из 32 в слоте, но вместе с ней упаковать нечего
    uint8 public override decimals;
    // totalSupply занимает следующий целый слот
    uint256 public override totalSupply;

    // далее типы string и mapping, контролировать упаковку нельзя
    string public override name;
    string public override symbol;
    
    mapping(address account => uint256 balance) public override balanceOf;
    mapping(address owner => 
            mapping(address spender => uint256 allowedSum)) public override allowance;

    // кастомная ошибка для функции _mint
    error ERC20InvalidAmount(uint256 amount);
    
    constructor(
        string memory _name, 
        string memory _symbol, 
        uint8 _decimals
    ) {
        name = _name;
        symbol = _symbol;
        decimals = _decimals;

        // назначаем владельцу контракта (деплоеру)
        // роли DEFAULT_ADMIN_ROLE и MINTER_ROLE
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        uint256 initialOwnerAmount = 1_000 * (10 ** decimals);

        // при развертывании контракта сразу начислим владельцу 1_000 токенов
        _mint(msg.sender, initialOwnerAmount);
    }

    /**
     * @dev Функция для минта токенов.
     * Доступна только с адресов с ролью MINTER_ROLE.
     * Если роли нет - вызывает revert с ошибкой AccessControlUnauthorizedAccount.
     */
    function mint(
        address _to,
        uint256 _amount
    ) external onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
    }

    function transfer(
        address _to, 
        uint256 _amount
    ) external override returns (bool) {
        _transfer(msg.sender, _to, _amount);

        return true;
    }

    function transferFrom(
        address _from, 
        address _to, 
        uint256 _amount
    ) external override returns (bool) {
        if (_from != msg.sender) {
            uint256 _allowance = allowance[_from][msg.sender];
            
            if (_allowance < _amount) {
                revert ERC20InsufficientAllowance(msg.sender, _allowance, _amount);
            }
            // Уменьшаем allowance для предотвращения бесконечного вывода
            unchecked {
                allowance[_from][msg.sender] = _allowance - _amount;
            }
        }

        _transfer(_from, _to, _amount);

        return true;
    }

    function approve(
        address _spender, 
        uint256 _amount
    ) external override returns (bool) {
        if (_spender == address(0)) {
            revert ERC20InvalidSpender(_spender);
        }

        allowance[msg.sender][_spender] = _amount;

        emit Approval(msg.sender, _spender, _amount);

        return true;
    }

    /**
     * @dev внутренняя функция для минта токенов.
     * Обязательно наличие модификатора onlyRole в вызывающей функции с ролью MINTER_ROLE!
     */
    function _mint(
        address _to,
        uint256 _amount
    ) private {
        // исключаем использование функции _mint для сжигания токенов.
        // Функционал сжигания для упрощения в контракте не предусмотрен
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(_to);
        }
        // предотвращаем минт нулевого количества токенов
        if (_amount == 0) {
            revert ERC20InvalidAmount(_amount);
        }

        balanceOf[_to] += _amount;
        totalSupply += _amount;

        emit Transfer(address(0), _to, _amount);
    }

    function _transfer(
        address _from, 
        address _to, 
        uint256 _amount
    ) private {
        if (_from == address(0)) {
            revert ERC20InvalidSender(_from);
        }
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(_to);
        }

        uint256 _balance = balanceOf[_from];
        if (_balance < _amount) {
            revert ERC20InsufficientBalance(_from, _balance, _amount);
        }

        unchecked {
            balanceOf[_from] = _balance - _amount;
        }
        balanceOf[_to] += _amount;

        emit Transfer(_from, _to, _amount);
    }
}