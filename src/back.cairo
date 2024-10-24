
#[starknet::contract]
mod MyNFT {
    //use openzeppelin::introspection::src5::SRC5Component;
    //use openzeppelin::token::erc721::ERC721Component;
    use starknet::ContractAddress;
    use starknet::get_caller_address;
    use zeroable::Zeroable;
    use starknet::contract_address_to_felt252;
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    use starknet::storage::{
        StoragePointerReadAccess, StoragePointerWriteAccess, Vec, VecTrait, MutableVecTrait,
        StorageMapReadAccess,StorageMapWriteAccess, Map
    };
}

#[storage]
struct Storage {
    payment_wallet:ContractAddress,
    subscription_fee_monthly:u256,
    subscription_fee_annual:u256,
    burn_fee:u256,
    owners: Map::<u256, ContractAddress, u256>, 
    trustees: Map::<u256,Vec<ContractAddress>>, 
    owner_cred: Map::<ContractAddress, OwnerCredentials>, //user credentials and registration details
    trial_end_dates: Map::<ContractAddress, felt252>, //stores when users free trial ends
    subscription_status: Map::<ContractAddress, felt252>, //monthly, annual , None
    last_payment_date: Map::<ContractAddress, felt252>, // stores the last payment date
    subscription_type:Map::<ContractAddress, felt252>, //monthly or annual
    nft_minting_fee_paid: Map::<ContractAddress, bool>,
    nft_burn_fee_paid: Map::<u256, bool>,
    owner_paid: bool,
    no_nfts:  u64,
    my_nfts: Map::<ContractAddress, Vec<u256>>, //how do i intend to store my NFTs in alist, i believe its by 
    sub_ended:bool,
    nft_uri: Map::<u256, felt252>,
    owner_addr:ContractAddress,
}


//----now i need to create an event right here------
//===i need to add all of my events in here=====



//==first is event to trigger email on registering the user
#[derive(Drop)]
struct OwnerCredentials {
    user_email:ByteArray,
    username:felt252,
    user_reg_date: felt252,
}


//===now another event is to add the user
//not yet pretty sure if i need the useradded event
#[derive(Drop, starknet::Event)]
struct UserAdded {
    user_email:ByteArray,
}

//we need to have the metadata structure for our NFT
//===will com eback to this later-----
#[derive(Drop, starknet::Event)]
struct UploadNFT {
    nft_name:felt252,
    assetType: felt252,
}


//now we want to have an event after burning an NFT we must trigger an event
#[derive(Drop, starknet::Event)]
struct BurnNFT {
    nft_name:felt252,
    documentID:felt252,
}

// another event right here is for adding trustee======
//i need the trustee email address for now mostly
//
#[derive(Drop, starknet::Event)]
struct Trustee {
    trusteee_address:ByteArray,
}

//---event to trigger after user has paid their subscription
#[derive(Drop, starknet::Event)]
struct SubscriptionPaid {
    user_address:ContractAddress,
    payment_type:felt252,
    payment_date:felt252,
}


struct Attributes {
    assetType: felt252,
    assetTitle: felt252,
    description: felt252,
    owner: ContractAddress,
    documentID: felt252,
    creationDate: felt252,
    legalStatus: felt252,
    associatedFiles: felt252,
    location: felt252,
    value: felt252,
    transferability: felt252,
    status: felt252,
    verification: felt252,
    documentHash: felt252,
}

//=====******* not yet clear properly-------
//first stop there, now go ahead and write the logic 
//first i will start with the authentication



//now to construct my smart contract, do you think i need to construct it with any initial
//params

#[constructor]
fn constructor(ref self: ContractState, owner_addr:ContractAddress,payment_wallet:ContractAddress) {
    self.payment_wallet.write(payment_wallet);
    self.subscription_fee_monthly.write(5 * stark_to_usd()); 
    //need a helper func to convert from usd to strks
    self.subscription_fee_annual.write(50 * stark_to_usd());
    self.burn_fee.write(10 * stark_to_usd());
    self.erc721.initializer('MyNFT', 'MyNFT'); 
    self.owner_addr.write(owner_addr);  
}

//check if this is the owner
fn is_this_owner(self:@ContractState) {
    assert(get_caller_address() == self.owner_addr.read(), "Not contract owner");
}

//all my funcs i need them to be private functions for now no need to be external
#[generate_trait]
impl MyNFTImpl of MyNFTTrait {
    fn register_user(ref self:ContractState, user_email:ByteArray, username:felt252, user_reg_date:felt252) {
        let caller = get_caller_address();
        //i need the contract address to register the user
        //after getting it i need to append it to the list of owners and then send
        //an email,  therefore get the username and email
        self.owner_cred.write(caller, OwnerCredentials {user_email, username, user_reg_date});

        //set the free trial expiration adte (2 weeks from registration)
        let trial_end = user_reg_date + (14*86400); //14 days * 86400 seconds/day
        self.trial_end_dates.write(caller, trial_end);

        //set subscription to None during the free trial
        self.subscription_status.write(caller, "None");

        //now with tht we have added i to th block chain as storage variables
        //==now trigger an event that user has been added
        self.emit(
            UserAdded {user_email:user_email}
        );
    }

    //before minting or burning NFTs you need to ensure the user has an active subscription
    //or has paid the required fee.
    fn check_payment_status(self:@ContractState, user_address:ContractAddress) -> bool {
        let trial_end  = self.trial_end_dates.read(user_address).unwrap_or_else("No trial data");

        let current_time = get_block_timestamp();
        if current_time < trial_end {
            //free trial is still active
            return true;
        }

        //if trial has endee, check for active subscription
        let subscription_type = self.subscription_type.read(user_address).unwrap_or_else("None");
        if subscription_type == "monthly" {
            //check if the monthly payment is upto date
            let last_payment = self.last_payment_date.read(user_address).unwrap_or_else("0");
            if current_time > last_payment + (30 * 86400) {
                //payment overdue, monthly payment required
                return false;
            }
        } else if subscription_type == "annual" {
            //check if the annual payment is up to date
            let last_payment = self.last_payment_date.read(user_address).unwrap_or_else("0");
            if current_time > last_payment + (365 * 86400) {
                //payment overdue, annual payment required
                return false;
            }
        } else {
            //no subscription user must choose a plan
            return false;
        }
        return true;
    }

    //function to handle subscription payments
    //user can select between a monthly or annual subscription and make payments accordingly
    fn pay_subscription(ref self: ContractState, user_address: ContractAddress, payment_type: felt252) {
        let fee: u256;
        
        if payment_type == "monthly" {
            fee = self.subscription_fee_monthly.read();
        } else if payment_type == "annual" {
            fee = self.subscription_fee_annual.read();
        } else {
            panic("Invalid payment type");
        }
        
        // Deduct the fee from the user's wallet
        transfer_funds(user_address, self.payment_wallet.read(), fee);
        
        // Update subscription details
        let current_time = get_block_timestamp();
        self.last_payment_date.write(user_address, current_time);
        self.subscription_type.write(user_address, payment_type);
        
        // Emit payment confirmation
        self.emit(SubscriptionPaid {
            user_address,
            payment_type,
            payment_date: current_time,
        });
    }
    //payment for burning NFT
    fn pay_burn_fee(ref self:ContractState, user_address:ContractAddress, token_id:u256) {
        let fee = self.burn_fee.read();
        //deduct the burn fee from the user's wallet
        transfer_funds(user_address, self.payment_wallet.read(), fee);
        //after deducting, mark the NFT as burned
        self.nft_burn_fee_paid.write(token_id, true);
        //emit event for burn fee payment
        self.emit(BurningFeePaid {
            token_id,
            amount:fee,
        })
    }

    //using starknet's ERC20 transfer function to move funds btn wallets
    fn transfer_funds(sender:ContractAddress, receiver:ContractAddress, amount:u256) {
        let erc20_address = starknet::native_token_address();
        let transfer_fn = erc20_address.transfer(sender, receiver, amount);

        assert(transfer_fn == true, "Transfer failed");
    }
    //===use this to check and ensure that user has enough balance to cover the fee, we can call 
    //balanceOf function before making the transfer.
    fn check_balance(user_address:ContractAddress, required_amount:u256) -> bool {
        let erc20_address = starknet::native_token_address();
        let balance = erc20_address.balance_of(user_address);
        return balance >= required_amount;
    }
    //=====liable to change=====
    fn mint_nft(ref self:ContractState, to:ContractAddress, token_id:u256, attr:Attributes) {
        is_this_owner(@self);
        //ensure the user has paid the one time minting fee
        let has_paid_minting_fee = self.nft_minting_fee_paid.read(to).unwrap_or_else(false);
        assert(has_paid_minting_fee == true, "Minting fee not paid");

        //mint the NFT now
        self._create_nft(token_id, to, attr);    
    }

    //to burn the NFT the user must have paid the burning fee which is about 10 USD
    fn burn_nft(ref self: ContractState, token_id:u256) {
        is_this_owner(@self);
        //ensure the burn fee has been paid\
        let has_paid_burn_fee = self.nft_burn_fee_paid.read(token_id).unwrap_or_else(false);
        assert(has_paid_burn_fee == true, "Burning fee not paid");

        //burn the NFT (same logic abit as above)
        self.erc721._burn(token_id);
        
    }


    //now a function to handle paying the burn fee
    //fn pay_burn_fee(ref self:ContractState, token_id:u256) {
    //    is_this_owner(@self);
        //deduct 10 usd (handled via) deducting from wallet
        //===todo now
    //    self.nft_burn_fee_paid.write(token_id, true);
        //emit an event for payment confirmation
    //    self.emit(BurningFeePaid {
    //        token_id,
    //        amount:10, //USD
    //    })
    //}
    //after registering the user can decide now to upload the nft, but before that
    //we need to first return the number of nfts by this user
    fn get_no_nfts(self:@ContractState) -> u64 {
        self.no_nfts.read();
    }

    //===function to get the nfts owned by a specific user
    fn get_user_nfts(self: @ContractState, user_address:ContractAddress) -> Vec<u256> {
        //fetch the list of NFTs owned by the user
        let user_nfts = self.my_nfts.read(user_address).unwrap_or_default();
        //return the list of NFT token IDS
        user_nfts
    }


    //now getting the trustess associated with a specific NFT by accessing the trustees mapping
    fn get_nft_trustess(self:@ContractState, token_id:u256) -> Vec<ContractAddress> {
        //fethc the list of trustees for the specific NFT
        let nft_trustees = self.trustees.read(token_id).unwrap_or_default();
        //retur the list of trustee addresses
        nft_trustees
    }
    //==combined func to show NFTs and their trustees for a user===
    //====first fetch the NFTs owned by the user
    //==== for each NFT, retrieve the associated trustees.
    fn get_user_nfts_and_trustees(self:@ContractState, user_address:ContractAddress) -> Vec<(u256, Vec<ContractAddress>)> {
        //fetch the users NFTs
        let user_nfts = self.get_user_nfts(user_address);

        //initialize a result vector to store NFT and trustee info
        let mut nft_trustees_list = Vec::new();
        //iterate through the user's NFTs and fetch trustees for each
        for token_id in user_nfts.iter() {
            let trustees = self.get_nft_trustees(*token_id); //get trustees for this NFt
            nft_trustees_list.push((*token_id, trustees));
        }

        //return the list of NFTs and their corresponding trustees
        nft_trustees_list
    }
    //upload Nft====very important function right there
    fn mint_nft(
        ref self: ContractState, 
        to: ContractAddress, 
        token_id: u256, 
        attr: Attributes, 
        is_l1_mint: bool
    ) {
        is_this_owner(@self);
        
        if is_l1_mint {
            self._create_nft(token_id, to, attr);
        } else {
            let empty_attr = Attributes {
                assetType: "carlogbook",
                assetTitle: "mycarlogbook",
                description: "official logbook for 2020 Toyota Corolla",
                owner: self.membership_address.read(),
                documentID: "VIN-XYZ12345",
                creationDate: "2024-01-01",
                legalStatus: "Verified",
                associatedFiles: "https://example.com/logbook.pdf",
                location: "kampala/zana",
                value: "1000 USD",
                transferability: "Transferable",
                status: "Active",
                verification: "verified",
                documentHash: "0xabcdef1234567890"
            };
            // Create the NFT with empty metadata for now
            self._create_nft(token_id, to, empty_attr);
            
            // Emit the event for NFT upload
            self.emit(
                UploadNFT {
                    nft_name: empty_attr.assetTitle,
                    assetType: empty_attr.assetType,
                }
            );
        }struct Attributes {
            assetType: felt252,
            assetTitle: felt252,
            description: felt252,
            owner: ContractAddress,
            documentID: felt252,
            creationDate: felt252,
            legalStatus: felt252,
            associatedFiles: felt252,
            location: felt252,
            value: felt252,
            transferability: felt252,
            status: felt252,
            verification: felt252,
            documentHash: felt252,
        }
    }

    //after creating the nft, we may want to burn the NFT
    fn burn_nft(ref self:ContractState, token_id:u256) {
        //for some to burn initially they have to be the owners
        is_this_owner(@self);
        assert(self.erc721._exists(token_id), 'INVALID_TOKEN_ID');

        //dstroying the NFT this may happen if the owner of the will dies or is sold
        let empty_attr = Attributes {
            assetType: "",
            assetTitle: "",
            description: "",
            owner:self."",
            documentID: "",
            creationDate: "",
            legalStatus: "",
            associatedFiles: "",
            location: "",
            value:"",
            transferability: "", 
            status: "Inactive",
            verification: "",
            documentHash: ""
        };
        self.attributes.write(token_id, empty_attr);
        self.erc721._burn(token_id);

        //aswell emit event after burning the NFT
        self.emit (
            BurnNFT {
                nft_name:empty_attr.assetTitle,
                documentID: empty_attr.documentID,
            }
        )
    }

    //now a function to enable adding trustees to the NFT
    fn add_trustee(ref self:ContractState, trustee_email: ByteArray, token_id:u256) {
        is_this_owner(@self); //ensure only the NFT owner can add trustees

        //store the trustee email temporaritly until confirmation
        self.trustees.write(token_id, trustees);

        //trigger an off-chain email invitation via an event
        self.emit(
            Trustee {
                trusteee_address: trustee_email,
            }
        )
    }
    //trustee confirmation is done after trustee confirms via email, and will then be added as 
    //trustee

    fn confirm_trustee(ref self:ContractState, token_id:u256, trustee_email:ByteArray) {
        let stored_trustee = self.trustees.read(token_id).unwrap_or_else("Invalid trustee");
        //ensure the trustee email matches the stored email
        assert(trustee_email == stored_trustee, "Trustee email mismatch");

        //add the trustee to the list of trustees for the specific NFT
        self.trustees.write(token_id, trustee_email);
        //send after confirming emit an event that confirms that the trustee has been added
        self.emit (
            Trustee {
                trusteee_address: trustee_email,
            }
        )
    }

    //implementing the payment functionality
    //1 - convert the fee to starknet token equivalent
    //2 - deduct the appropriate amount of stark from the users wallet
    //3 - send the amount to a preset wallet address

}



