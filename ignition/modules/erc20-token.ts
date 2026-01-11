import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

/**
 * Модуль деплоя ERC20Token с UUPS прокси.
 * Деплоит реализацию контракта и прокси, инициализирует контракт.
 */
export default buildModule('ERC20TokenModule', (m) => {
  // Параметры токена
  const tokenName = m.getParameter('tokenName', 'YSERC20TokenUpgradable');
  const tokenSymbol = m.getParameter('tokenSymbol', 'YSERC20TUP');
  const tokenDecimals = m.getParameter('tokenDecimals', 18);

  // Деплой первой версии реализации контракта
  const implementation = m.contract('ERC20Token');

  // Подготовка данных для инициализации первой версии контракта
  const initData = m.encodeFunctionCall(implementation, 'initialize', [
    tokenName,
    tokenSymbol,
    tokenDecimals,
  ]);

  /**
   * Деплой прокси контракта из OpenZeppelin.
   *
   * ВАЖНО:
   * Прокси контракт не создается отдельно в проекте, так как используется
   * стандартный ERC1967Proxy из библиотеки OpenZeppelin.
   *
   * ERC1967Proxy - это минималистичный прокси контракт, который:
   * - хранит адрес реализации в специальном storage слоте (EIP-1967);
   * - делегирует все вызовы в контракт реализации через delegatecall;
   * - позволяет обновлять реализацию через функцию upgradeTo/upgradeToAndCall.
   */
  const proxy = m.contract('@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy', [
    implementation,
    initData,
  ]);

  return { implementation, proxy };
});
