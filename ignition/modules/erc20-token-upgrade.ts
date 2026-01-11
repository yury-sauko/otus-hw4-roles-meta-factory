import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

/**
 * Модуль для обновления ERC20Token до версии V2.
 * Используется после деплоя прокси контракта для обновления реализации.
 */
export default buildModule('ERC20TokenUpgradeModule', (m) => {
  // Адрес прокси контракта (должен быть указан при запуске)
  const proxyAddress = m.getParameter('proxyAddress');

  // Деплой новой реализации V2
  const implementationV2 = m.contract('ERC20TokenV2');

  // Получаем прокси контракт по адресу
  const proxy = m.contractAt(
    '@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol:ERC1967Proxy',
    proxyAddress,
  );

  // Подготовка данных для инициализации V2
  const initV2Data = m.encodeFunctionCall(implementationV2, 'initializeV2', []);

  // Вызываем upgradeToAndCall на прокси для обновления реализации
  m.call(proxy, 'upgradeToAndCall', [implementationV2, initV2Data]);

  return { implementationV2, proxy };
});
