import { buildModule } from '@nomicfoundation/hardhat-ignition/modules';

/**
 * Модуль деплоя CounterFactory контракта.
 * Factory создает базовую реализацию Counter и позволяет создавать клоны по EIP-1167.
 */
export default buildModule('CounterFactoryModule', (m) => {
  const factory = m.contract('CounterFactory');

  return { factory };
});
