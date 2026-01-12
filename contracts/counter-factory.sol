// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/proxy/Clones.sol";

import "./Counter.sol";

/**
 * Публичный Factory контракт (без контроля доступа) для создания клонированных контрактов
 * Counter по стандарту EIP-1167 (Minimal Proxy).
 */
contract CounterFactory {
    /**
     * @dev Адрес базовой реализации контракта Counter.
     * Используется как мастер-копия для всех клонов.
     */
    address public immutable implementation;

    /**
     * @dev Массив адресов всех созданных клонов.
     */
    address[] private clones;

    /**
     * @dev Событие, которое эмитируется при создании нового клона.
     * @param clone Адрес созданного клона.
     * @param creator Адрес создателя клона.
     */
    event CloneCreated(address indexed clone, address indexed creator);

    /**
     * @dev Конструктор Factory контракта.
     * Деплоит базовую реализацию Counter контракта.
     */
    constructor() {
        implementation = address(new Counter());
    }

    /**
     * @dev Создает новый клон контракта Counter.
     * Использует библиотеку Clones из OpenZeppelin для создания минимального прокси контракта.
     * @return clone Адрес созданного клона.
     */
    function createClone() external returns (address clone) {
        clone = Clones.clone(implementation);
        
        clones.push(clone);
        
        emit CloneCreated(clone, msg.sender);
        
        return clone;
    }

    /**
     * @dev Создает новый клон контракта Counter с детерминированным адресом.
     * Адрес клона вычисляется на основе salt, что позволяет предсказать адрес до создания.
     * @param salt Соль для детерминированного создания адреса.
     * @return clone Адрес созданного клона.
     */
    function createCloneDeterministic(bytes32 salt) external returns (address clone) {
        clone = Clones.cloneDeterministic(implementation, salt);
        
        clones.push(clone);
        
        emit CloneCreated(clone, msg.sender);
        
        return clone;
    }

    /**
     * @dev Вычисляет адрес клона, который будет создан с указанным salt
     * при помощи функции createCloneDeterministic.
     * Используется для предсказания адреса до фактического создания клона контракта.
     * @param salt Соль для вычисления адреса.
     * @return Адрес, который будет иметь клон при создании с этим salt.
     */
    function predictCloneAddress(bytes32 salt) external view returns (address) {
        return Clones.predictDeterministicAddress(implementation, salt, address(this));
    }

    /**
     * @dev Возвращает количество созданных клонов.
     * @return Количество созданных клонов.
     */
    function getClonesCount() external view returns (uint256) {
        return clones.length;
    }

    /**
     * @dev Возвращает адрес клона по индексу.
     * @param index Индекс клона в массиве.
     * @return Адрес клона по указанному индексу.
     */
    function getClone(uint256 index) external view returns (address) {
        return clones[index];
    }

    /**
     * @dev Возвращает все адреса созданных клонов.
     * @return Массив адресов всех созданных клонов.
     */
    function getAllClones() external view returns (address[] memory) {
        return clones;
    }
}
