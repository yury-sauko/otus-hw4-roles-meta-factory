// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/Strings.sol";

import "./erc20-token.sol";

/**
 * Пример обновленной версии контракта ERC20Token.
 * Демонстрирует процесс обновления контракта через UUPS прокси.
 * 
 * ВАЖНО: При обновлении контракта необходимо сохранять:
 * 1. Порядок переменных состояния (storage layout).
 * 2. Все существующие функции и их сигнатуры.
 * 3. Совместимость с предыдущей версией.
 * 
 * В этом примере добавлена новая функция burn и версия контракта.
 */

contract ERC20TokenV2 is ERC20Token {
    /**
     * @dev Версия контракта для отслеживания обновлений.
     * Используется uint64 для соответствия типу модификатора reinitializer.
     */
    uint64 public constant VERSION = 2;

    /**
     * @dev Кастомная ошибка для функции burn.
     */
    error ERC20InsufficientBalanceForBurn(address account, uint256 balance, uint256 amount);
    
    // Кастомные ошибки для проверки версии при обновлении.
    error InvalidVersion(uint64 currentVersion, uint64 newVersion);
    error ContractVersionNotFound(address newImplementation);

    /**
     * @dev Инициализатор для версии V2.
     * Вызывается при обновлении контракта.
     * ВАЖНО: Не используем initializer, так как контракт уже инициализирован.
     * Используем reinitializer с константой VERSION.
     * 
     * Примечание: VERSION - константа, поэтому не требует установки.
     * Функция оставлена для совместимости и возможных будущих инициализаций.
     */
    function initializeV2() public reinitializer(VERSION) {}

    /**
     * @dev Возвращает версию контракта, используя константу VERSION.
     * Это позволяет не переопределять функцию version в последующих версиях.
     */
    function version() public pure override returns (string memory) {
        return string.concat("version ", Strings.toString(VERSION));
    }

    /**
     * @dev Функция для сжигания токенов.
     * Новая функциональность, добавленная в версии V2.
     * @param _amount Количество токенов для сжигания.
     */
    function burn(uint256 _amount) external {
        address account = msg.sender;
        uint256 accountBalance = balanceOf[account];
        
        if (accountBalance < _amount) {
            revert ERC20InsufficientBalanceForBurn(account, accountBalance, _amount);
        }

        unchecked {
            balanceOf[account] = accountBalance - _amount;
        }
        totalSupply -= _amount;

        emit Transfer(account, address(0), _amount);
    }

    /**
     * @dev Переопределяем функцию _authorizeUpgrade для V2.
     * Сохраняем ту же логику контроля доступа и добавляем проверку версии.
     */
    function _authorizeUpgrade(address newImplementation) 
        internal 
        view
        override 
        onlyRole(DEFAULT_ADMIN_ROLE) 
    {
        // Проверка версии новой реализации.
        // Используем статический вызов для получения версии без изменения состояния.
        (bool success, bytes memory returnData) = newImplementation.staticcall(
            abi.encodeWithSignature("VERSION()")
        );
        
        // Если вызов успешен и версия получена, сверяем последовательность версий.
        if (success && returnData.length > 0) {
            uint64 newVersion = abi.decode(returnData, (uint64));
            uint64 currentVersion = VERSION;
            
            // Проверяем, что новая версия больше текущей на единицу.
            // Это сохраняет последовательность версий и предотвращает откат к более старым.
            if (newVersion != currentVersion + 1) {
                revert InvalidVersion(currentVersion, newVersion);
            }
        // Если вызов не успешен или версия не получена, возвращаем ошибку.
        } else {
            revert ContractVersionNotFound(newImplementation);
        }
    }
}
