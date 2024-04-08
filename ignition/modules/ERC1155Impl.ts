import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

const ERC1155ImplModule = buildModule("ERC1155ImplModule", (m) => {
  const e1155 = m.contract("ERC1155Impl", [""], {});

  return { e1155 };
});

export default ERC1155ImplModule;
