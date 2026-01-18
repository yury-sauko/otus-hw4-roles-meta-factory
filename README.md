## Урок 20, план ДЗ

### 1. Создайте контракт с уровнями доступа.

См. [`contracts/erc20-token.sol`](contracts/erc20-token.sol)

Примененные в контракте механизмы контроля доступа:

- условные выражения с оператором `revert` для отклонения транзакций при несоблюдении условий;
- модификаторы видимости `private`, `external`;
- механизм ограничения доступа на основе ролей (`RBAC`) с использованием `AccessControlUpgradeable`
  из `OpenZeppelin`. Минимальный набор ролей, в обучающих целях;

### 2. Внедрите мета-транзакции в контракт.

См. [`contracts/erc20-token.sol#L173`](contracts/erc20-token.sol#L173)

Реализовано через `EIP-712` для типизированных подписей и `nonce` для защиты от повторного использования мета-транзакций.

### 3. Реализуйте функцию permit в ERC20 токене по стандарту ERC2612.

Выполнено. См. [`contracts/erc20-token.sol#L312`](contracts/erc20-token.sol#L312)

### 4. Создайте обновляемый контракт, используя один из стандартов Transparent, UUPS либо Beacon.

Выполнено по стандарту `UUPS` (Universal Upgradeable Proxy Standard). См. [`contracts/erc20-token.sol`](contracts/erc20-token.sol), [`contracts/erc20-token-v2.sol`](contracts/erc20-token-v2.sol) и [`UPGRADE_GUIDE.md`](UPGRADE_GUIDE.md).

### 5. Напишите Factory контракт, который создаёт клонированные контракты.

Выполнено по стандарту `EIP-1167` (Minimal Proxy). См. [`contracts/counter-factory.sol`](contracts/counter-factory.sol) и [`FACTORY_GUIDE.md`](FACTORY_GUIDE.md).

### 6. Созданный вами контракт должен быть протестирован (минимальным набором тестов).

Выполнено. См. тесты на Solidity (`contracts/*.t.sol`) и [`TESTING_GUIDE.md`](TESTING_GUIDE.md).
