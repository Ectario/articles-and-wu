// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {Diamond} from "../src/contracts/Diamond.sol";
import {DevToken} from "../src/contracts/tokens/DevToken.sol";
import {DevLead} from "../src/contracts/tokens/DevLead.sol";
import {DiamondCutFacet} from "../src/contracts/facets/DiamondCutFacet.sol";
import {DiamondLoupeFacet} from "../src/contracts/facets/DiamondLoupeFacet.sol";
import {RandomizerFacet} from "../src/contracts/facets/RandomizerFacet.sol";
import {RefreshLeaderFacet} from "../src/contracts/facets/RefreshLeaderFacet.sol";
import {MoneyGameFacet} from "../src/contracts/facets/MoneyGameFacet.sol";
import {PoolFacet} from "../src/contracts/facets/PoolFacet.sol";
import {IDiamondCut} from "../src/contracts/interfaces/IDiamondCut.sol";
import {IFacet} from "../src/contracts/interfaces/IFacet.sol";
import {Setup} from "../src/contracts/Setup.sol";
import {ERC20} from "../src/contracts/external_lib/ERC20.sol";
import {Ownable} from "../src/contracts/external_lib/Ownable.sol";

// cast interface src/contracts/facets/RefreshLeaderFacet.sol
interface IRefreshLeaderFacet {
    function getSelectors() external pure returns (bytes4[] memory selectors);
    function refreshLeader(address newLeader) external;
    function setTokensAddresses(address devtoken, address devlead) external;
}

interface ISetDiamond {
    function setDiamondAddr(address diamond) external;
}

interface IInitPool {
    function initPool(address devtoken, address devlead) external;
}

contract DeployDiamond is Script {
    address public constant mafia = 0xd99453Cc6931f922Ee749474bb5336d028E8B811;
    address SETUP_CONTRACT;
    address deployer;

    function run() external {
        vm.startBroadcast();
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(privateKey);

        DevToken devToken = new DevToken(deployer, 10000, mafia);
        DevLead devLead = new DevLead();

        DiamondCutFacet cutFacet = new DiamondCutFacet();
        Diamond diamond = new Diamond(address(devLead), address(cutFacet));

        bytes[20] memory devkeys;
        devkeys[0] = hex"ef2091a8dedb05c108f063bd79253deb368843119f44a899fb3646d725fb29c979b60c6e2edccd4474ce57c75dc61856d73611895b577caff7244674b1ea0d3a1c";
        devkeys[1] = hex"523578c1dbcc7cc250a1f5a9a3e69573eea3c7a58f806a08c7a72c99810adc5b710b067134c2582e21837c393a7d881ee5e74d9932c9c170c4bc595c1d560e1c1b";
        devkeys[2] = hex"037844472dc11598a36a1939820488b356ae3a2e496271fad61e7e83d7a9b20008f51cc62c6e9c12bc4fadc8319de427ccdba1514dd4d008908633f0f45e8a271b";
        devkeys[3] = hex"f9baab17c6efb1f824a352c8941d659098a69e119d3b70afe59be9bbedaec0106351088f15c1613a8f4f246d505c1b2c5b77e05e9cd6f82f6d16b6778cb6db581c";
        devkeys[4] = hex"c97f54dbacd1bbf6175520ca3ffdec29a3131ce0757c47cea3bf6e41432586767eb347c045c045dd908ace0ff6de26fcef27e050d304aae63263ac8283bea3201c";
        devkeys[5] = hex"db0d74c6461c104ec5e3154666b85d2ab5cb4dd0515c9f8b4b4660a3803876b10be21dd65cc7fee51d98745f55f7540c447c8647a22e901173ac29b16f9d25be1c";
        devkeys[6] = hex"9d68d957c952374db8ae8bd56f83173b58ad73e8ace1e042a9737bc06eea822e16d406cb0de14f049e529071bc8f6ce6f0e45cedbf2d4a52776dcc2d355043461b";
        devkeys[7] = hex"2ded7eccbc0e0be6c2527afe9a4a833cb3620a1535a256240af31bf283e4266753e13ee01325672d51ab6f9b7ecdc06847566ae7adc7084dc9cdaae03685f9e61b";
        devkeys[8] = hex"ddee75dc96bd34207915d34686a2bbcccf609cd0423efeb6528e09cfca9b6ed20c5a33ea21b79ec1e2beed0dbb999a5cdb2c269290ad32c71baa15dc2b59a7041b";
        devkeys[9] = hex"d6987c784fd4ac6ce0203de5183679ee5e4b55af9c5a759eeb004c63fb01b8493af064001f218fe645e8cc48a5a8d9a7370dbadae493a8ed5b9ae4fb27f124ad1c";
        devkeys[10] = hex"7b48d5d840ea46e33571b8339025c020ebfe459ad722591a2f4f03db1177803a7a60edb2c67898eb83e26c6efc777a29e5a3a70545e51d207d86d012d000d78d1b";
        devkeys[11] = hex"9ab76db9d6dafc2714108dafb8ff0598423242fbfbe56e20bf5c77ab6f611ac74dc9e8d973d6e5a5ab10da46604e0f37f589cc21dd32c974493b89544886a0c21b";
        devkeys[12] = hex"5f5026768f069bfd83c359cc9bff0e4d88a37175de030e98686a8b6b23b5280b0b5ba9b53ed123bb8160c10e0a5b4c4925429e359debb7528f654a1509c09d8a1c";
        devkeys[13] = hex"f8b795ebdde30d6d109c2a6b187cebfaee97d940a90050c6c09ff50cb4fbc8750b2a4536600f95746556fd601e90909f07142036cc6ed062995c998c861c71fc1c";
        devkeys[14] = hex"1bd5a8763449ff855c6f6d81e985291370de6d75914a2f59a85ce1aa95bf96707b7d2e3bce445915e401642127b4d4869398bc0ba05799878ef1538ab88099c91b";
        devkeys[15] = hex"239d077ed5651e5f07a5ed309f435b5612b60f793a7b3ccf0dedf4252a1e3c9b2edf8c4a3727f89296759c78cdbdbbe2d1f5adb3ececc3f95749ef171452d1ef1b";
        devkeys[16] = hex"bb7af6787221043fce7d991ffad74db7bd18a56546e3799b7a22ea979250e5915eef90cc73157d6848d29dbc8fd0b554b7574d8173a5d90113deebbade83123c1c";
        devkeys[17] = hex"b581dd405502babfbe376d94355fb69c4a10eb8bebd70ef347336a2e8e99bf585cae8ad83223fb6a216213a5cdc8ba8235e32cd5be1eaa5059bf7adfd1b78e5f1c";
        devkeys[18] = hex"67d7707476e9b95624b32fc17df512f438713186f37f6663f40c27d569a8892317568852abe770a1b1e8c1ade9f1ab75eb2a49aac9dbd2529c7dc5f9367ca8261c";
        devkeys[19] = hex"bf631d730d7a42fe76f03af56e7a06bcae86d788ac50ec7865e973b6af23daa267d39f12affe4d797767b0d998bda2667f6c7ef2320dbd03a50a2a07252d51631b";

        PoolFacet poolFacet = new PoolFacet(devkeys, address(diamond));
        DiamondLoupeFacet loupeFacet = new DiamondLoupeFacet();
        RandomizerFacet randomizer = new RandomizerFacet();
        MoneyGameFacet moneyGame = new MoneyGameFacet();
        RefreshLeaderFacet refresh = new RefreshLeaderFacet();

        (bool success, ) = payable(address(poolFacet)).call{value: 100 ether}("");
        require(success, "ETH transfer failed");

        devToken.initPoolAuthorization(address(diamond));
        ERC20(devToken).transfer(address(diamond), ERC20(devToken).balanceOf(deployer));


        IDiamondCut.FacetCut[] memory cuts = new IDiamondCut.FacetCut[](5);
        cuts[0] = IDiamondCut.FacetCut({
            facetAddress: address(loupeFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(address(loupeFacet)).getSelectors()
        });
        cuts[1] = IDiamondCut.FacetCut({
            facetAddress: address(poolFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(address(poolFacet)).getSelectors()
        });
        cuts[2] = IDiamondCut.FacetCut({
            facetAddress: address(randomizer),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(address(randomizer)).getSelectors()
        });
        cuts[3] = IDiamondCut.FacetCut({
            facetAddress: address(moneyGame),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(address(moneyGame)).getSelectors()
        });
        cuts[4] = IDiamondCut.FacetCut({
            facetAddress: address(refresh),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: IFacet(address(refresh)).getSelectors()
        });

        IDiamondCut(address(diamond)).diamondCut(cuts, address(0), "");

        IRefreshLeaderFacet(address(diamond)).setTokensAddresses(address(devToken), address(devLead));
        ISetDiamond(address(diamond)).setDiamondAddr(address(diamond));
        IInitPool(address(diamond)).initPool(address(devToken),address(devLead));
        Ownable(devLead).transferOwnership(address(diamond));

        SETUP_CONTRACT = address(new Setup(address(devToken), address(devLead), address(diamond), address(poolFacet))); 

        vm.stopBroadcast();

        console.log("DEPLOYED SETUP:");
        console.log(SETUP_CONTRACT);

    }
}
