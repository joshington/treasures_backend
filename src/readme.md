
===== generally the Dapp offers confidentiality as a service ===

System architecture

Auth
    -> under this we need to obtain the users wallet address - using braavos or argentx
    -> ask for user's username and then their email aswell
    -> after that trigger an event letting user know that they have signed up on the Dapp
    -> user confirms then you can redirect them to the upload section.

    ==> use users wallet address by getting it from argentx or braavos



Upload section
    -> Hit the upload button
    -> after uploading indicate that it was successful, NFT upload success
    -> redirect to the NFTs list
    -> add trustee button on the NFTs

Add Trustee
    -> Ask for the email of the trustee  to be added.
    -> On adding trustee email send email to the trustee
    -> Trustee may not need to add their wallet address.
    -> Once they have been added as trustees they can only view they can edit the NFT

Subscription
    -> Give a trial for about 2 weeks, after which user has to pay 5 usd per month 
    -> On minting => there is a one time pay that has to be paid 
    -> The trustee can aswell mint the NFT, but minting is only done once
    -> by either the owner or the NFT


Technical breakdown
    what are the storage variables that i need, these include;
    1 - owner, since the owner can die and trustee takes over.
        store the owner credentials as well
    2 - trustees - can only be a maximum of 2 this will be a list.


    3 - balance - but this depends on the subscription chosen
    4 - nft_uri => on minting, i have to generate the NFT uri
    5 - reg date - to help track the trial period.
    6 - paid -bool - to track whether user paid or not
    


Now my events
    -> Trigger a Register user event - this is when user has finished signing up -      this sends email to user
    -> event on uploading the NFT successfully
    -> on adding trustee trigger event to send email to trustee added
    -> Trigger an event aswell on minting the NFT
    ->On expiry of trial period 
    -> On end of trial period a day before, send email to user to subscribe

functionalities 
    -> register user
            -> pick users wallet - first thing to do
            -> pcik email -> store to database 
            -> pick the username -> store to db aswell
            -> send email to user, sort of like welcoming the user
            -> then redirect them to the upload screen


    ===== so here i meant to mint === give the NFT value in otherwards
    ->  Upload Nft functionality
            -> first the NFT must be a digital asset
            -> Then upload -> initially we are going to store the NFTs onchain
            -> then we will use offchain storage
            -> trigger event that NFt storage was a success - to return something to user screen
            -> Remember every NFT must have metadata -> name of Nft -> timestamp(upload time/date)

    ->  Subscription
            -> payment monthly or anually 
            -> call the wallet used so that to collect the payment
            -> On success - return list of NFTs page 
            -> On failure - return that payment failed
    
    -> Assign trustee 
            -> let user put in the trustees' email
            -> then on assigning - send email
            -> On user accepting - add the trustee under the docs trustees
            -> rememmber they can only view initially

    -> Mint NFT
            -> first owner has to make a one time pay before minting
            -> i think minting will be based on the token uri


    -> to implement a payment system in starknet with the logic 
            - free trial period (2 weeks for new users)
            - monthly fee of 5 USD or an anuual fee of 50 usd after the free trial
            - a on etim epayment of 10 USD for burning an NFT.
            




        