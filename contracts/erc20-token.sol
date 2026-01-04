// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

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
 * Реализовано через EIP-712 для типизированных подписей
 * и nonce для защиты от повторного использования мета-транзакций.
 * 
 * 3. Реализуйте функцию permit в ERC20 токене по стандарту ERC2612.
 * Выполнено.
 */

contract ERC20Token is IERC20, IERC20Metadata, IERC20Errors, AccessControl, EIP712 {
    /**
     * @dev Расширим методы типа bytes32 методами из библиотеки ECDSA
     * по восстановлению адреса подписанта.
     */
    using ECDSA for bytes32;

    // Переменные состояния расположим в правильном порядке
    // для оптимизации упаковки в storage.

    // Константы в storage не упаковываются.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    
    /**
     * @dev Хеш определения типа для структуры Transfer в соответствии с EIP-712.
     * Используется для формирования итогового хеша сообщения, 
     * которое подписывает пользователь, для мета-транзакции transfer.
     */
    bytes32 private constant TRANSFER_TYPEHASH = 
        keccak256("Transfer(address from,address to,uint256 amount,uint256 nonce,uint256 deadline)");
    
    /**
     * @dev Хеш определения типа для структуры Approve в соответствии с EIP-712.
     * Используется для формирования итогового хеша сообщения, 
     * которое подписывает пользователь, для мета-транзакции approve.
     */
    bytes32 private constant APPROVE_TYPEHASH = 
        keccak256("Approve(address owner,address spender,uint256 amount,uint256 nonce,uint256 deadline)");
    
    /**
     * @dev Хеш определения типа для структуры Permit в соответствии с ERC2612.
     * Используется для формирования итогового хеша сообщения, 
     * которое подписывает пользователь, для функции permit.
     */
    bytes32 private constant PERMIT_TYPEHASH = 
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    // decimals занимает 1 байт из 32 в слоте, но вместе с ней упаковать нечего.
    uint8 public override decimals;
    // totalSupply занимает следующий целый слот.
    uint256 public override totalSupply;

    // Далее типы string и mapping, контролировать упаковку нельзя.
    string public override name;
    string public override symbol;
    
    mapping(address account => uint256 balance) public override balanceOf;
    mapping(address owner => 
            mapping(address spender => uint256 allowedSum)) public override allowance;
    
    /**
     * @dev Маппинг nonce для защиты от повторного использования мета-транзакций.
     */
    mapping(address account => uint256 nonce) public nonces;

    /**
     * @dev Кастомная ошибка для функции _mint. 
     */
    error ERC20InvalidAmount(uint256 amount);
    // Кастомные ошибки для мета-транзакций и permit.
    error MetaTransactionExpired(uint256 deadline);
    error PermitExpired(uint256 deadline);
    error InvalidSignature();
    error InvalidNonce(address account, uint256 providedNonce, uint256 expectedNonce);
    
    // Помимо инициализаций в теле конструктора, инициализируем конструктор базового контракта
    // EIP712, где "1" - назначаемая версия домена для подписи.
    constructor(
        string memory _name, 
        string memory _symbol, 
        uint8 _decimals
    ) EIP712(_name, "1") {
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

    /**
     * @dev Мета-транзакция для transfer.
     * Позволяет выполнить transfer от имени подписанта без оплаты газа.
     * @param _from Адрес отправителя (подписанта).
     * @param _to Адрес получателя.
     * @param _amount Количество токенов.
     * @param _deadline Срок действия транзакции (timestamp).
     * @param _signature Подпись EIP-712 от _from.
     */
    function metaTransfer(
        address _from,
        address _to,
        uint256 _amount,
        uint256 _deadline,
        bytes memory _signature
    ) external returns (bool) {
        // Проверяем валидность срока действия мета-транзакции.
        if (block.timestamp > _deadline) {
            revert MetaTransactionExpired(_deadline);
        }

        uint256 currentNonce = nonces[_from];
        bytes32 structHash = keccak256(abi.encode(
            TRANSFER_TYPEHASH,
            _from,
            _to,
            _amount,
            currentNonce,
            _deadline
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        // Восстанавливаем адрес подписанта из финального хеша и подписи.
        address signer = hash.recover(_signature);

        // Проверяем, что адрес подписанта совпадает с адресом отправителя.
        if (signer != _from || signer == address(0)) {
            revert InvalidSignature();
        }

        // Увеличиваем nonce после успешной проверки подписи.
        nonces[_from]++;

        // Выполняем перевод токенов от имени подписанта.
        _transfer(_from, _to, _amount);

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
     * @dev Мета-транзакция для approve.
     * Позволяет выполнить approve от имени подписанта без оплаты газа.
     * @param _owner Адрес владельца (подписанта).
     * @param _spender Адрес получателя разрешения.
     * @param _amount Количество токенов.
     * @param _deadline Срок действия транзакции (timestamp).
     * @param _signature Подпись EIP-712 от _owner.
     */
    function metaApprove(
        address _owner,
        address _spender,
        uint256 _amount,
        uint256 _deadline,
        bytes memory _signature
    ) external returns (bool) {
        // Проверяем валидность срока действия мета-транзакции.
        if (block.timestamp > _deadline) {
            revert MetaTransactionExpired(_deadline);
        }

        if (_spender == address(0)) {
            revert ERC20InvalidSpender(_spender);
        }        

        uint256 currentNonce = nonces[_owner];
        bytes32 structHash = keccak256(abi.encode(
            APPROVE_TYPEHASH,
            _owner,
            _spender,
            _amount,
            currentNonce,
            _deadline
        ));
        bytes32 hash = _hashTypedDataV4(structHash);
        // Восстанавливаем адрес подписанта из финального хеша и подписи.
        address signer = hash.recover(_signature);

        // Проверяем, что адрес подписанта совпадает с адресом владельца.
        if (signer != _owner || signer == address(0)) {
            revert InvalidSignature();
        }

        // Увеличиваем nonce после успешной проверки подписи.
        nonces[_owner]++;

        // Устанавливаем allowance для получателя разрешения от имени подписанта.
        allowance[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);

        return true;
    }

    /**
     * @dev Функция permit по стандарту ERC2612.
     * Позволяет владельцу токенов подписать разрешение для spender'а без выполнения транзакции
     * (и соответственно без оплаты газа за транзакцию).
     * @param _owner Адрес владельца токенов (подписанта).
     * @param _spender Адрес получателя разрешения.
     * @param _value Количество токенов.
     * @param _deadline Срок действия разрешения (timestamp).
     * @param _v Компонент v подписи ECDSA.
     * @param _r Компонент r подписи ECDSA.
     * @param _s Компонент s подписи ECDSA.
     */
    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // Проверяем валидность срока действия разрешения.
        if (block.timestamp > _deadline) {
            revert PermitExpired(_deadline);
        }

        if (_spender == address(0)) {
            revert ERC20InvalidSpender(_spender);
        }

        uint256 currentNonce = nonces[_owner];
        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            _owner,
            _spender,
            _value,
            currentNonce,
            _deadline
        ));
        bytes32 hash = _hashTypedDataV4(structHash);        
        // Восстанавливаем адрес подписанта из финального хеша и компонентов подписи.
        address signer = ecrecover(hash, _v, _r, _s);

        // Проверяем, что адрес подписанта совпадает с адресом владельца.
        if (signer != _owner || signer == address(0)) {
            revert InvalidSignature();
        }

        // Увеличиваем nonce после успешной проверки подписи.
        nonces[_owner]++;

        // Устанавливаем allowance для получателя разрешения от имени подписанта.
        allowance[_owner][_spender] = _value;

        emit Approval(_owner, _spender, _value);
    }

    /**
     * @dev внутренняя функция для минта токенов.
     * Обязательно наличие модификатора onlyRole в вызывающей функции с ролью MINTER_ROLE!
     */
    function _mint(
        address _to,
        uint256 _amount
    ) private {
        // Исключаем использование функции _mint для сжигания токенов.
        // Функционал сжигания для упрощения в контракте не предусмотрен.
        if (_to == address(0)) {
            revert ERC20InvalidReceiver(_to);
        }
        // Предотвращаем минт нулевого количества токенов.
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