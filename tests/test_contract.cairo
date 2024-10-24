//use starknet::ContractAddress;

//use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

//use treasures_backend::IHelloStarknetSafeDispatcher;
//use treasures_backend::IHelloStarknetSafeDispatcherTrait;
//use treasures_backend::IHelloStarknetDispatcher;
//use treasures_backend::IHelloStarknetDispatcherTrait;

//fn deploy_contract(name: ByteArray) -> ContractAddress {
//    let contract = declare(name).unwrap().contract_class();
//    let (contract_address, _) = contract.deploy(@ArrayTrait::new()).unwrap();
//    contract_address
//}

//#[test]
//fn test_increase_balance() {
//    let contract_address = deploy_contract("HelloStarknet");

//    let dispatcher = IHelloStarknetDispatcher { contract_address };

//    let balance_before = dispatcher.get_balance();
//    assert(balance_before == 0, 'Invalid balance');

//dispatcher.increase_balance(42);

//    let balance_after = dispatcher.get_balance();
//    assert(balance_after == 42, 'Invalid balance');
//}

//#[test]
//#[feature("safe_dispatcher")]
//fn test_cannot_increase_balance_with_zero_value() {
//    let contract_address = deploy_contract("HelloStarknet");

//    let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

//    let balance_before = safe_dispatcher.get_balance().unwrap();
//    assert(balance_before == 0, 'Invalid balance');

//    match safe_dispatcher.increase_balance(0) {
//        Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
//        Result::Err(panic_data) => {
//            assert(*panic_data.at(0) == 'Amount cannot be 0', *panic_data.at(0));
//        }
//    };
//}


use starknet::ContractAddress;

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

use starknet::test::testing_contract::StarkNetContract;
use starknet::test::testing_environment::{
    StarkNetTestingEnvironment, StarkNetTestingState, start_test_env,
};

use starknet::contract_address::contract_address_to_felt252;
use mynft::MyNFT;  //assuming the contract is in a module mynft

//start the test
#[test]
fn test_register_user() {
    //initialize the test envt
    let env = StarkNetTestingEnvironment::start();

    //deploy the contract
    let contract_addr = env.deploy(MyNFT::class_hash());


    //simulate user registration
    let user_email  = "user@example.com";
    let username = "testuser";
    let reg_date = get_block_timestamp();

    //call the contract function
    env.call_contract(contract_addr, MyNFT::register_user, (
        user_email.into(),
        username().into(),
        reg_date.into()
    ));

    // Fetch the user's stored credentials and assert correctness
    let user_credentials = env.call_contract(contract_addr, MyNFT::get_user_credentials, ());
    assert(user_credentials.user_email == user_email.into(), "User email should match");
    assert(user_credentials.username == username.into(), "Username should match");

    // Check that the trial period is set correctly (14 days from registration)
    let trial_end = env.call_contract(contract_addr, MyNFT::get_trial_end_date, ());
    assert(trial_end == (reg_date + 14 * 86400).into(), "Trial end date should be 14 days after registration");
}
