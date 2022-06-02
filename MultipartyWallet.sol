// SPDX-License-Identifier: GPL-3.0

pragma solidity  >=0.7.0 < 0.9.0 ;

contract MultipartyWallet {

    event Deposit(address indexed sender, uint amount,uint balance);
    event SubmitTransaction(
        uint indexed txIndex
    );
    event ApproveProposal(address indexed owner,uint indexed txIndex);
    event ExecuteProposal(address indexed owner,uint indexed txIndex);

 struct Transaction {
        address to;
        uint value;
        bytes data;
        bool executed;
    }

address Administrator;
address[] walletOwners;
mapping(uint => mapping(address => bool)) approvals;
uint public reqApprovals;
Transaction[] transactions;

modifier onlyOwners() {
    bool isOwner = false;
    for(uint i =0; i<walletOwners.length;i++){
        if(walletOwners[i] == msg.sender){
            isOwner = true;
            break;
        }
    }
        require(isOwner == true, "only wallet owners can perform it");
        _;
    }

modifier txExists(uint _txIndex) {
        require(_txIndex < transactions.length, "tx does not exist");
        _;
    }
modifier notApproved(uint _txIndex){
        require(!approvals[_txIndex][msg.sender],"tx already approved");
        _;
    }

modifier notExecuted(uint _txIndex) {
        require(!transactions[_txIndex].executed, "tx already executed");
        _;
    }


modifier onlyAdmin(){
    require(msg.sender == Administrator,"Only admin can call this function");
    _;
}

constructor(){
    Administrator = payable(msg.sender);
    walletOwners.push(Administrator);
    reqApprovals = 60;   //required percentage set to 60
}

 function addWalletOwner(address owner) public onlyAdmin{
     for(uint i=0;i<walletOwners.length;i++){
         if(walletOwners[i] == owner){
             revert("cannot add deplicate owners");
         }
     }
     walletOwners.push(owner);
    
 } //only admin can add owner

 function removeWalletOwner(address owner) public onlyAdmin{
     bool hasBeenFound = false;
     uint ownerIndex;
     for(uint i=0;i<walletOwners.length;i++){
         if(walletOwners[i]==owner){
             hasBeenFound = true;
             ownerIndex = i;
             break;
         }
     }
     require(hasBeenFound == true,"wallet owner not detected");
     walletOwners[ownerIndex] = walletOwners[walletOwners.length-1];
     walletOwners.pop();
 } //only admin can remove owner


 function submitTransaction(
        address _to,
        uint _value,
        bytes calldata _data
    ) external onlyOwners {
        transactions.push(Transaction(
            {to: _to,
            value: _value,
            data:_data,
            executed:false
            }));
        emit SubmitTransaction(transactions.length-1);
    }  // any of owner can submit a new transaction 


     function approveProposal(uint _txIndex)
        external
        onlyOwners
        txExists(_txIndex)
        notApproved(_txIndex)
        notExecuted(_txIndex)
    {
        approvals[_txIndex][msg.sender] = true;
        emit ApproveProposal(msg.sender, _txIndex);
    } // remaining owners can approve the proposal



function _getApprovalPercent(uint _txIndex)private view returns (uint percent){
    uint count;
    for(uint i;i< walletOwners.length;i++){
        if(approvals[_txIndex][walletOwners[i]]){
             count = count+1;
            percent = (count/walletOwners.length)*100;
        }
    }
}  // check weather required owners have approved the proposal


    function executeProposal(uint _txIndex)
        external
        txExists(_txIndex)
        notExecuted(_txIndex)
    {
        require(_getApprovalPercent(_txIndex) >= reqApprovals,"approvals less than required");
        Transaction storage transaction = transactions[_txIndex];

        transaction.executed = true;

        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "tx failed");

        emit ExecuteProposal( msg.sender,_txIndex);
    }
 // proposal can be executed if it satisfies the approval percentage.

function deposit() payable external{
    emit Deposit(msg.sender,msg.value,address(this).balance);
}

 function getWalletOwners()public view onlyAdmin returns (address[] memory){
     return walletOwners;
 }

 function setReqApprovals(uint _reqApprovals) external onlyAdmin{
  reqApprovals = _reqApprovals;
 } // Admin can change the percentage of approval needed for execution.

}