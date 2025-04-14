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

        bytes[20] memory devkeys; // REDACTED

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
