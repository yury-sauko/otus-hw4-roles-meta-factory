# Руководство по обновлению контракта ERC20Token (стандарт UUPS)

Это руководство описывает процесс деплоя и обновления контракта ERC20Token, реализованного по стандарту UUPS (Universal Upgradeable Proxy Standard).

## Архитектура

Контракт использует стандарт UUPS для обновляемости:

- **Первая версия реализации контракта** (`erc20-token.sol`) - содержит бизнес-логику
- **Прокси контракт** (`ERC1967Proxy`) - делегирует вызовы в реализацию, хранит состояние. Отдельно в проекте не создавался, используется стандартный ERC1967Proxy из библиотеки OpenZeppelin
- **Вторая версия реализации** (`erc20-token-v2.sol`) - версия с дополнительным функционалом (метод burn для сжигания токенов)

## Деплой контракта

### 1. Деплой первоначальной версии

```bash
npx hardhat ignition deploy ignition/modules/erc20-token.ts --network <network>
```

С кастомными параметрами:

```bash
npx hardhat ignition deploy ignition/modules/erc20-token.ts \
  --parameters '{"ERC20TokenModule":{"tokenName":"MyToken","tokenSymbol":"MTK","tokenDecimals":18}}' \
  --network <network>
```

Это создаст:

- Контракт реализации `ERC20Token`
- Прокси контракт `ERC1967Proxy`, который указывает на реализацию
- Контракт будет инициализирован через `initialize()`

### 2. Получение адресов

После деплоя сохраните адреса:

- `implementation` - адрес контракта реализации
- `proxy` - адрес прокси контракта (этот адрес используется для взаимодействия)

## Обновление контракта до V2

### 1. Подготовка новой реализации

Убедитесь, что:

- Новый контракт (`ERC20TokenV2`) наследуется от старого (`ERC20Token`)
- Сохранен порядок переменных состояния (storage layout)
- Добавлена функция `initializeV2()` с модификатором `reinitializer(2)`

### 2. Деплой новой реализации и обновление

```bash
npx hardhat ignition deploy ignition/modules/erc20-token-upgrade.ts \
  --parameters '{"ERC20TokenUpgradeModule":{"proxyAddress":"0x<адрес_прокси>"}}' \
  --network <network>
```

Это выполнит:

1. Деплой новой реализации `ERC20TokenV2`
2. Вызов `upgradeToAndCall()` на прокси для обновления
3. Инициализацию V2 через `initializeV2()`

### 3. Проверка обновления

После обновления проверьте:

- Адрес прокси остался прежним
- Все данные сохранены (балансы, allowances, nonces)
- Новая функциональность доступна (например, `burn()`)

## Важные моменты

### Права доступа

Обновление контракта может выполнить только адрес с ролью `DEFAULT_ADMIN_ROLE`:

- Проверка выполняется в функции `_authorizeUpgrade()`
- Используется модификатор `onlyRole(DEFAULT_ADMIN_ROLE)`

### Инициализация

- **V1**: Используется `initialize()` с модификатором `initializer`
- **V2**: Используется `initializeV2()` с модификатором `reinitializer(2)`
- Каждая версия должна иметь свой инициализатор с уникальным номером версии

## Примеры использования

### Взаимодействие с контрактом через прокси

```typescript
import { createPublicClient, http } from 'viem';
import { mainnet } from 'viem/chains';

const client = createPublicClient({
  chain: mainnet,
  transport: http(),
});

// Используйте адрес ПРОКСИ для всех взаимодействий
const proxyAddress = '0x...';

// Вызов функций через прокси
const balance = await client.readContract({
  address: proxyAddress,
  abi: erc20TokenAbi,
  functionName: 'balanceOf',
  args: [userAddress],
});
```

### Обновление через скрипт

```typescript
import { createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';

const account = privateKeyToAccount('0x...');
const client = createWalletClient({
  account,
  transport: http(),
});

// Получаем интерфейс прокси
const proxy = await client.getContractAt('ERC1967Proxy', proxyAddress);

// Деплоим новую реализацию
const implementationV2 = await deployContract(client, 'ERC20TokenV2');

// Обновляем реализацию через прокси
await proxy.write.upgradeToAndCall([
  implementationV2.address,
  encodeFunctionData({
    abi: erc20TokenV2Abi,
    functionName: 'initializeV2',
    args: [],
  }),
]);
```

## Устранение неполадок

### Ошибка: "Storage layout incompatible"

**Причина**: Изменен порядок переменных состояния.

**Решение**: Восстановите правильный порядок переменных в новой версии.

### Ошибка: "AccessControlUnauthorizedAccount"

**Причина**: Адрес не имеет роли `DEFAULT_ADMIN_ROLE`.

**Решение**: Убедитесь, что вы используете адрес с правами администратора.

### Ошибка: "Initializable: contract is already initialized"

**Причина**: Попытка вызвать `initialize()` повторно.

**Решение**: Используйте `reinitializer(2)` для V2 вместо `initializer`.

## Дополнительные ресурсы

- [OpenZeppelin UUPS Documentation](https://docs.openzeppelin.com/contracts-stylus/uups-proxy)
- [EIP-1822: Universal Upgradeable Proxy Standard](https://eips.ethereum.org/EIPS/eip-1822)
- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
