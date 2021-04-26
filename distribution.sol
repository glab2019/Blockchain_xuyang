pragma solidity ^0.4.0;

contract TaskDistribution
{
    uint sumOfUser = 1; //用户地址映射需要从1开始,使用时要减一
    uint sumOfTask = 0; //目前发布的任务总数
    uint sumOfApply = 0; //进行申请的任务书
    uint sumOfTaskPublisher = 0;
    mapping(address => uint) addressToId; //用于将地址转换为用户ID，ID从1开始，但用户结构体下标从0开始
    mapping(address => bool) addressToBool; //记录该账户是否已发布任务
    uint duration = 1 days; //每次结算时间
    uint startTime; //本次测试开始时间
    
    // 用户信息
    struct User
    {
        uint id; //用户ID
        address account; //用户地址
        uint[] reputation; //名誉值
        uint indexOfreputation; //由于名誉值会初始化为60,所以index从1开始记录
        //uint time; 用户能提供的最大时间，暂时不用
        uint n; // 三个代价参数
        uint o;
        uint k;
    }
    
    // 任务信息
    struct Task
    {
        string description; //任务描述
        address owner; //任务发布者
        uint a; //三个任务质量要求系数
        uint b;
        uint c;
        uint budget; //任务预算
    }
    
    // 用户申请任务情况
    struct UserToTask
    {
        address account; //申请账户
        uint TaskId; //申请任务ID
        uint bidMoney; //申请者出价
        uint quality; //根据用户自身情况以及任务要求估算的任务质量
        uint xij; // 分配函数决定该任务分配给该用户的执行时间
    }
    
    User[] public users; //注册用户集
    Task[] public tasks; //发布任务集
    UserToTask[] public taskSituation; //用户申请任务情况集
    
    constructor() public
    {
        startTime = block.timestamp;
    }
    
    // 用户注册
    function register(uint _n, uint _o, uint _k) public
    {
        require(addressToId[msg.sender] == 0, "you have already registered");
        uint[] memory reputation = new uint[](10);
        User memory person = User(sumOfUser, msg.sender, reputation, 1, _n, _o, _k);
        users.push(person);
        addressToId[msg.sender] = sumOfUser;
        users[sumOfUser-1].reputation[0] = 60;
        sumOfUser ++;
    }

    // 用户发布任务，只有注册用户才能发布任务
    function publishTask(string _description, uint _a, uint _b, uint _c, uint _budget) public
    {
        require(addressToId[msg.sender] != 0, "you have to registerd to publish task");
        Task memory tk = Task(_description, msg.sender, _a, _b, _c, _budget);
        tasks.push(tk);
        sumOfTask ++;
        
        if(addressToBool[msg.sender] == false)
        {
            addressToBool[msg.sender] = true;
            sumOfTaskPublisher ++;
        }
    }

    // 用户申请任务
    function applyTask(uint _taskId, uint _bidMoney) public
    {
        require(tasks[_taskId].owner != msg.sender, "you can't apply your task");
        UserToTask memory utt = UserToTask(msg.sender, _taskId, _bidMoney, 0, 0);
        taskSituation.push(utt);
        sumOfApply ++;
    }
    
    
    mapping(address => uint) sumSij; //用户地址映射其当前Sij之和
    // 进行任务分配
    function distributeTask() public
    {
        uint i;
        uint sij; //计算值是真实值的1000倍
        uint taskID;
        
        for(i=0;i<sumOfApply;i++)
        {
            sij = taskSituation[i].quality * 1000 / taskSituation[i].bidMoney;
            sumSij[taskSituation[i].account] += sij;
        }

        for(i=0;i<sumOfApply;i++)
        {
            taskID = taskSituation[i].TaskId;
            sij = taskSituation[i].quality * 1000 / taskSituation[i].bidMoney;
            taskSituation[i].xij = (tasks[taskID].budget * sij * 1000) / (taskSituation[i].bidMoney * sumSij[taskSituation[i].account]); //计算值是真实值的1000倍
            // 添加名誉值到分子
        }
    }
    
    // 更新名誉值
    function updateReputation() public
    {
        uint i;
        uint j;
        uint aveReputation;
        uint sumReputation = 0;
        uint indexOfreputation; 
        uint newReputation;
        
        for(i=0;i<sumOfUser-1;i++)
        {
            if(sumSij[users[i].account] == 0)
                continue;
                
            indexOfreputation = users[i].indexOfreputation;
            aveReputation = 0;
            newReputation = sumSij[users[i].account] / sumOfTaskPublisher;
            
            for(j=0;j<indexOfreputation;j++)
                aveReputation += users[i].reputation[j];
                
            aveReputation = aveReputation / indexOfreputation;
            
            if(indexOfreputation == 10)
            {
                for(j=0;j<9;j++)
                {
                    users[i].reputation[j] = users[i].reputation[j+1];
                }
                users[i].reputation[9] = 4 * aveReputation / 10 + 6 * newReputation / 10;
                sumReputation += users[i].reputation[9];
            }
            else
            {
                users[i].reputation[indexOfreputation] = 4 * aveReputation / 10 + 6 * newReputation / 10;
                sumReputation += users[i].reputation[indexOfreputation];
                indexOfreputation ++;
                users[i].indexOfreputation = indexOfreputation;
            }
        }
        
        for(i=0;i<sumOfUser-1;i++)
        {
            if(sumSij[users[i].account] == 0)
                continue;
            users[i].reputation[indexOfreputation-1] =  users[i].reputation[indexOfreputation-1] * 100 / sumReputation;
        }
    }
    
    // 用于获取某个用户某个下标的名誉值
    function getReputation(address _account, uint index) public view returns(uint)
    {
        uint id = addressToId[_account] - 1;
        return(users[id].reputation[index]);
    }
    
    // 用于清空环境，主要是本轮申请情况记录
    function clear() public
    {
        uint i;
        for(i=0;i<sumOfApply;i++)
        {
            delete sumSij[taskSituation[i].account];
        }
        delete taskSituation;
        sumOfApply = 0;
    }
    
    // 估计的任务完成情况，测试中等同于实际完成情况
    function estimateTaskResult() public 
    {
        //require(block.timestamp >= startTime + duration, "you have to wait");
        
        uint i;
        
        for(i=0;i<sumOfApply;i++)
        {
            uint userID = addressToId[taskSituation[i].account] - 1;
            uint taskID = taskSituation[i].TaskId;
            taskSituation[i].quality = users[userID].n * tasks[taskID].a + users[userID].o * tasks[taskID].b + users[userID].k * tasks[taskID].c;
        }
    }
    
    // 以下代码仅用于测试
    
    function registerTest(address _account, uint _n, uint _o, uint _k) private
    {
        //require(addressToId[msg.sender] == 0, "you have already registered");
        uint[] memory reputation = new uint[](10);
        User memory person = User(sumOfUser, _account, reputation, 1, _n, _o, _k);
        users.push(person);
        addressToId[_account] = sumOfUser;
        users[sumOfUser-1].reputation[0] = 60;
        sumOfUser ++;
    }

    function publishTaskTest(address _account,string _description, uint _a, uint _b, uint _c, uint _budget) private
    {
        //require(addressToId[msg.sender] != 0, "you have to registerd to publish task");
        Task memory tk = Task(_description, _account, _a, _b, _c, _budget);
        tasks.push(tk);
        sumOfTask ++;
        
        if(addressToBool[_account] == false)
        {
            addressToBool[_account] = true;
            sumOfTaskPublisher ++;
        }
    }
    
    function applyTaskTest(address _account, uint _taskId, uint _bidMoney) private
    {
        //require(tasks[_taskId].owner != msg.sender, "you can't apply your task");
        UserToTask memory utt = UserToTask(_account, _taskId, _bidMoney, 0, 0);
        taskSituation.push(utt);
        sumOfApply ++;
    }
    
    function autoRegisterAndPublish() public
    {
        address publishAccount1 = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        address publishAccount2 = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
        address publishAccount3 = 0x4B20993Bc481177ec7E8f571ceCaE8A9e22C02db;
        address applyAccount1 = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
        address applyAccount2 = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2;
        
        registerTest(publishAccount1, 1, 2, 3);
        registerTest(publishAccount2, 2, 3, 1);
        registerTest(publishAccount3, 3, 2, 1);
        
        registerTest(applyAccount1, 1, 2, 3);
        registerTest(applyAccount2, 2, 3, 1);
        
        publishTaskTest(publishAccount1, "task", 4, 5, 6, 10);
        publishTaskTest(publishAccount2, "task", 5, 4, 6, 15);
        publishTaskTest(publishAccount3, "task", 6, 4, 5, 20);
    }
    
    function autoApplyAndcalculate(uint _bid1, uint _bid2, uint _bid3, uint _bid4, uint _bid5, uint _bid6) public
    {
        address applyAccount1 = 0x78731D3Ca6b7E34aC0F824c42a7cC18A495cabaB;
        address applyAccount2 = 0x617F2E2fD72FD9D5503197092aC168c91465E7f2;
        
        applyTaskTest(applyAccount1, 0, _bid1);
        applyTaskTest(applyAccount1, 1, _bid2);
        applyTaskTest(applyAccount1, 2, _bid3);
        applyTaskTest(applyAccount2, 0, _bid4);
        applyTaskTest(applyAccount2, 1, _bid5);
        applyTaskTest(applyAccount2, 2, _bid6);
        
        estimateTaskResult();
        distributeTask();
        updateReputation();
    }
}






