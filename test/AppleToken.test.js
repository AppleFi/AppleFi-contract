const { expectRevert } = require('@openzeppelin/test-helpers');
const AppleToken = artifacts.require('AppleToken');

contract('AppleToken', ([alice, bob, carol]) => {
    beforeEach(async () => {
        this.apple = await AppleToken.new({ from: alice });
    });

    it('should have correct name and symbol and decimal', async () => {
        const name = await this.apple.name();
        const symbol = await this.apple.symbol();
        const decimals = await this.apple.decimals();
        assert.equal(name.valueOf(), 'AppleToken');
        assert.equal(symbol.valueOf(), 'APPLE');
        assert.equal(decimals.valueOf(), '18');
    });

    it('should only allow owner to mint token', async () => {
        await this.apple.mint(alice, '100', { from: alice });
        await this.apple.mint(bob, '1000', { from: alice });
        await expectRevert(
            this.apple.mint(carol, '1000', { from: bob }),
            'Ownable: caller is not the owner',
        );
        const totalSupply = await this.apple.totalSupply();
        const aliceBal = await this.apple.balanceOf(alice);
        const bobBal = await this.apple.balanceOf(bob);
        const carolBal = await this.apple.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '100');
        assert.equal(bobBal.valueOf(), '1000');
        assert.equal(carolBal.valueOf(), '0');
    });

    it('should supply token transfers properly', async () => {
        await this.apple.mint(alice, '100', { from: alice });
        await this.apple.mint(bob, '1000', { from: alice });
        await this.apple.transfer(carol, '10', { from: alice });
        await this.apple.transfer(carol, '100', { from: bob });
        const totalSupply = await this.apple.totalSupply();
        const aliceBal = await this.apple.balanceOf(alice);
        const bobBal = await this.apple.balanceOf(bob);
        const carolBal = await this.apple.balanceOf(carol);
        assert.equal(totalSupply.valueOf(), '1100');
        assert.equal(aliceBal.valueOf(), '90');
        assert.equal(bobBal.valueOf(), '900');
        assert.equal(carolBal.valueOf(), '110');
    });

    it('should fail if you try to do bad transfers', async () => {
        await this.apple.mint(alice, '100', { from: alice });
        await expectRevert(
            this.apple.transfer(carol, '110', { from: alice }),
            'ERC20: transfer amount exceeds balance',
        );
        await expectRevert(
            this.apple.transfer(carol, '1', { from: bob }),
            'ERC20: transfer amount exceeds balance',
        );
    });
  });
