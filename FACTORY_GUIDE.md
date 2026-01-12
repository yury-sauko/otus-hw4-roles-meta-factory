## CounterFactory (EIP-1167)

### Описание

`CounterFactory` использует паттерн **EIP-1167 (Minimal Proxy)** для создания легковесных клонов контракта `Counter`. `CounterFactory` выполнен публичным, без контроля доступа к функциям.

### Преимущества

- **Экономия газа**: Создание клона стоит ~45,000 газа вместо ~200,000+ для полного деплоя
- **Одна реализация**: Все клоны используют одну базовую реализацию
- **Независимое состояние**: Каждый клон имеет свое собственное состояние
- **Отслеживание**: Factory хранит массив адресов всех созданных клонов и содержит функции для доступа к этим адресам

### Как это работает

1. Factory деплоит базовую реализацию `Counter` один раз в конструкторе
2. При вызове `createClone()` создается минимальный прокси контракт (~55 байт)
3. Прокси делегирует все вызовы в базовую реализацию через `delegatecall`
4. Состояние хранится в прокси, код выполняется из реализации
5. Адрес каждого созданного клона сохраняется в массиве `clones`
6. При создании клона эмитируется событие `CloneCreated`

## Использование

### Базовое использование

```solidity
// Деплой Factory
CounterFactory factory = new CounterFactory();

// Создание клона
address clone1 = factory.createClone();

// Работа с клоном
Counter counter1 = Counter(clone1);
counter1.inc(); // x = 1
counter1.incBy(5); // x = 6

// Создание другого клона (независимое состояние)
address clone2 = factory.createClone();
Counter counter2 = Counter(clone2);
counter2.inc(); // x = 1 (независимо от clone1)
```

### Детерминированные адреса

Для предсказуемых адресов необходимо использовать `createCloneDeterministic()`:

```solidity
bytes32 salt = keccak256("my-unique-salt");

// Предсказываем адрес до создания
address predicted = factory.predictCloneAddress(salt);

// Создаем клон с предсказуемым адресом
address clone = factory.createCloneDeterministic(salt);

assert(clone == predicted); // Адреса совпадают
```

### Отслеживание клонов

Factory предоставляет функции для работы с созданными клонами:

```solidity
// Получаем количество созданных клонов
uint256 count = factory.getClonesCount(); // например, 5

// Получаем клон по индексу
address firstClone = factory.getClone(0);
address secondClone = factory.getClone(1);

// Получаем все клоны сразу
address[] memory allClones = factory.getAllClones();
// allClones = [clone1, clone2, clone3, ...]
```

### Публичные переменные

#### `implementation`

Адрес базовой реализации контракта Counter (immutable).

```solidity
address public immutable implementation;
```

**Доступ:** Только чтение

**Пример:**

```solidity
address impl = factory.implementation();
```

### События

#### `CloneCreated`

Эмитируется при создании нового клона.

```solidity
event CloneCreated(address indexed clone, address indexed creator);
```

**Параметры:**

- `clone` - Адрес созданного клона (indexed)
- `creator` - Адрес создателя клона (indexed)

**Пример использования:**

```solidity
// Подписка на событие в JavaScript/TypeScript
factory.on("CloneCreated", (clone, creator) => {
    console.log(`Clone created: ${clone} by ${creator}`);
});
```

## Деплой

```bash
npx hardhat ignition deploy ignition/modules/counter-factory.ts --network <network>
```

После деплоя вы получите адрес Factory контракта, который можно использовать для создания клонов.

## Примеры использования

### Создание множества счетчиков для разных пользователей

```solidity
CounterFactory factory = CounterFactory(factoryAddress);

// Создаем счетчики для разных пользователей
address user1Counter = factory.createClone();
address user2Counter = factory.createClone();
address user3Counter = factory.createClone();

// Каждый счетчик независим
Counter(user1Counter).inc();        // user1Counter.x = 1
Counter(user2Counter).incBy(10);    // user2Counter.x = 10
Counter(user3Counter).inc();        // user3Counter.x = 1

// Получаем информацию о созданных клонах
uint256 totalClones = factory.getClonesCount(); // 3
address[] memory allUserCounters = factory.getAllClones();
```

### Использование детерминированных адресов

```solidity
// Создаем клон с предсказуемым адресом для конкретного пользователя
bytes32 userSalt = keccak256(abi.encodePacked("user-", userId));

// Предсказываем адрес до создания
address predictedAddress = factory.predictCloneAddress(userSalt);

// Создаем клон
address userCounter = factory.createCloneDeterministic(userSalt);

// Адреса совпадают
assert(userCounter == predictedAddress);
```

### Итерация по всем клонам

```solidity
// Получаем все клоны
address[] memory allClones = factory.getAllClones();

// Работаем с каждым клоном
for (uint256 i = 0; i < allClones.length; i++) {
    Counter counter = Counter(allClones[i]);
    uint256 currentValue = counter.x();
    // Делаем что-то с каждым счетчиком
}
```

### Отслеживание создания клонов через события

```solidity
// В JavaScript/TypeScript с ethers.js
const filter = factory.filters.CloneCreated();
const events = await factory.queryFilter(filter);

events.forEach((event) => {
    console.log(`Clone: ${event.args.clone}`);
    console.log(`Creator: ${event.args.creator}`);
});
```

## Безопасность

1. **Базовая реализация**: Должна быть проверена и не содержать уязвимостей, так как все клоны используют ее код
2. **Неизменяемость**: Базовая реализация не может быть изменена после деплоя Factory (immutable)
3. **Состояние**: Каждый клон имеет независимое состояние, изменения в одном клоне не влияют на другие
4. **Доступ к клонам**: Массив `clones` является `private`, доступ возможен только через публичные функции
5. **События**: Все создания клонов логируются через событие `CloneCreated` для прозрачности

## Дополнительные ресурсы

- [EIP-1167: Minimal Proxy Standard](https://eips.ethereum.org/EIPS/eip-1167)
- [OpenZeppelin Clones Library](https://docs.openzeppelin.com/contracts/5.x/api/proxy#Clones)
- [Solidity Documentation - Delegatecall](https://docs.soliditylang.org/en/latest/introduction-to-smart-contracts.html#delegatecall-callcode-and-libraries)
