import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can create new content",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('drift_zone', 'create-content', [
                types.ascii("Relaxing Nature Sounds"),
                types.ascii("ASMR"),
                types.ascii("Calming forest and river sounds"),
                types.uint(100)
            ], deployer.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(0);
        
        let contentResponse = chain.callReadOnlyFn(
            'drift_zone',
            'get-content',
            [types.uint(0)],
            deployer.address
        );
        
        const content = contentResponse.result.expectSome().expectTuple();
        assertEquals(content['title'], "Relaxing Nature Sounds");
    }
});

Clarinet.test({
    name: "Can purchase subscription and access content",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create content
        let block = chain.mineBlock([
            Tx.contractCall('drift_zone', 'create-content', [
                types.ascii("Meditation Guide"),
                types.ascii("Meditation"),
                types.ascii("Guided meditation session"),
                types.uint(50)
            ], deployer.address)
        ]);
        
        // Purchase subscription
        let subscriptionBlock = chain.mineBlock([
            Tx.contractCall('drift_zone', 'purchase-subscription', 
                [], wallet1.address)
        ]);
        
        subscriptionBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify subscription status
        let subStatus = chain.callReadOnlyFn(
            'drift_zone',
            'has-active-subscription',
            [types.principal(wallet1.address)],
            wallet1.address
        );
        
        subStatus.result.expectOk().expectBool(true);
        
        // Access content with subscription
        let accessBlock = chain.mineBlock([
            Tx.contractCall('drift_zone', 'purchase-content', [
                types.uint(0)
            ], wallet1.address)
        ]);
        
        accessBlock.receipts[0].result.expectOk().expectBool(true);
    }
});

Clarinet.test({
    name: "Can purchase and rate content",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const wallet1 = accounts.get('wallet_1')!;
        
        // Create content
        let block = chain.mineBlock([
            Tx.contractCall('drift_zone', 'create-content', [
                types.ascii("Meditation Guide"),
                types.ascii("Meditation"),
                types.ascii("Guided meditation session"),
                types.uint(50)
            ], deployer.address)
        ]);
        
        // Purchase content
        let purchaseBlock = chain.mineBlock([
            Tx.contractCall('drift_zone', 'purchase-content', [
                types.uint(0)
            ], wallet1.address)
        ]);
        
        purchaseBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Rate content
        let rateBlock = chain.mineBlock([
            Tx.contractCall('drift_zone', 'rate-content', [
                types.uint(0),
                types.uint(5)
            ], wallet1.address)
        ]);
        
        rateBlock.receipts[0].result.expectOk().expectBool(true);
        
        // Verify rating
        let contentResponse = chain.callReadOnlyFn(
            'drift_zone',
            'get-content',
            [types.uint(0)],
            deployer.address
        );
        
        const content = contentResponse.result.expectSome().expectTuple();
        assertEquals(content['rating'], types.uint(5));
    }
});
