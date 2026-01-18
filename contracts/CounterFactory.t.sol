// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";

import {CounterFactory} from "./counter-factory.sol";
import {Counter} from "./Counter.sol";

contract CounterFactoryTest is Test {
    CounterFactory factory;

    // Функция setUp выполняется перед каждым тестом и подготавливает окружение.
    // Инициализируем переменную factory экземпляром CounterFactory.
    function setUp() public {
        factory = new CounterFactory();
    }

    function test_ImplementationIsSet() public view {
        address impl = factory.implementation();
        require(impl != address(0), "Implementation should be set");
    }

    function test_CreateClone() public {
        address clone = factory.createClone();
        
        require(clone != address(0), "Clone address should not be zero");
        require(clone != factory.implementation(), "Clone should differ from implementation");
        
        // Приводим адрес клона к типу имплементации Counter,
        // что позволяет вызывать методы имплементации,
        // но чтение состояния происходит из хранилища клона
        Counter counter = Counter(clone);
        require(counter.x() == 0, "Initial value should be 0");
    }

    function test_CreateMultipleClones() public {
        address clone1 = factory.createClone();
        address clone2 = factory.createClone();
        
        require(clone1 != clone2, "Clones should have different addresses");
        require(factory.getClonesCount() == 2, "Should have 2 clones");
    }

    function test_CreateCloneDeterministic() public {
        bytes32 salt = keccak256("test-salt");
        address predicted = factory.predictCloneAddress(salt);
        address clone = factory.createCloneDeterministic(salt);
        
        require(clone != address(0), "Clone address should not be zero");
        require(clone == predicted, "Clone address should match prediction");        
    }

    function test_GetClone() public {
        address clone1 = factory.createClone();
        address clone2 = factory.createClone();
        
        require(factory.getClone(0) == clone1, "First clone should match");
        require(factory.getClone(1) == clone2, "Second clone should match");
    }

    function test_GetAllClones() public {
        address clone1 = factory.createClone();
        address clone2 = factory.createClone();
        
        address[] memory clones = factory.getAllClones();
        require(clones.length == 2, "Should return 2 clones");
        require(clones[0] == clone1, "First clone should match");
        require(clones[1] == clone2, "Second clone should match");
    }

    function test_CloneIsIndependent() public {
        address clone1 = factory.createClone();
        address clone2 = factory.createClone();
        
        Counter counter1 = Counter(clone1);
        Counter counter2 = Counter(clone2);
        
        counter1.inc();
        counter2.incBy(5);
        
        require(counter1.x() == 1, "First clone should have value 1");
        require(counter2.x() == 5, "Second clone should have value 5");
    }
}
