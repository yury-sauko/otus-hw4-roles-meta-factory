# Описание

Проект использует Hardhat 3 Beta с поддержкой Foundry-совместимых Solidity тестов и TypeScript интеграционных тестов.

## Типы тестов

Проект поддерживает два типа тестов:

### 1. Solidity тесты (Foundry-совместимые)

- **Расположение**: `contracts/*.t.sol`
- **Фреймворк**: Foundry (forge-std)
- **Использование**: Unit-тесты для смарт-контрактов
- **Преимущества**: Быстрые, дешевые, полный контроль над EVM

### 2. TypeScript тесты

- **Расположение**: `test/*.ts`
- **Фреймворк**: Node.js test runner (node:test)
- **Использование**: Интеграционные тесты с реальными транзакциями
- **Преимущества**: Проверка событий, взаимодействие с сетью

## Запуск тестов

### Базовые команды

```bash
# Запустить все тесты
npx hardhat test

# Запустить только Solidity тесты
npx hardhat test solidity

# Запустить только TypeScript тесты
npx hardhat test nodejs
```

### Запуск конкретных тестов

```bash
# Запустить конкретный файл тестов
npx hardhat test contracts/Counter.t.sol
npx hardhat test contracts/ERC20Token.t.sol

# Запустить тесты по паттерну имени
npx hardhat test --grep "Mint"
npx hardhat test --grep "Upgrade"
```

## Отладка тестов

### Вывод значений в консоль

```solidity
import {console} from "forge-std/Test.sol";

function test_Debug() public {
    uint256 value = counter.x();
    console.log("Counter value:", value);
}
```

### Использование `console.log`

```solidity
console.log("Address:", address(token));
console.log("Balance:", balance);
console.log("String:", "test");
console.log("Uint256:", amount);
```

## Полезные команды

```bash
# Компиляция контрактов перед тестами
npx hardhat compile

# Очистка кэша и артефактов
npx hardhat clean
```
