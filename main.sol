// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

contract FairShare {
    struct Member {
        address memberAddress;
        uint256 depositAmount;
        uint256 timeConstraint;
        bool isOwner;
        bool hasDeposited;
    }

    Member[] public members;
    uint256 public currentMonth = 1;
    uint256 public totalPayouts = 0;
    uint256 public totalMembers = 0;
    uint256 public totalRequiredPayouts;
    uint256 public poolBalance = 0;
    bool public systemOpen = false;
    uint256 public systemOpenTimestamp;

    event MemberAdded(address indexed memberAddress, uint256 timeConstraint);
    event Deposit(address indexed memberAddress, uint256 amount);
    event SavingsPoolComplete(uint256 totalPayouts);

    constructor(
        uint256 _totalRequiredPayouts,
        uint256 _minMembers,
        uint256 _waitDays
    ) payable {
        require(
            _totalRequiredPayouts > 0,
            "Total required payouts must be greater than zero"
        );
        require(_minMembers > 0, "Minimum members must be greater than zero");
        require(_waitDays > 0, "Wait days must be greater than zero");
        totalRequiredPayouts = _totalRequiredPayouts;
        members.push(Member(msg.sender, 0, block.timestamp, true, false));
        emit MemberAdded(msg.sender, block.timestamp);
        totalMembers++;
        poolBalance = msg.value;
        systemOpenTimestamp = block.timestamp + (_waitDays * 1 days);

        if (totalMembers >= _minMembers) {
            systemOpen = true;
        }
    }

    function deposit() public payable {
        Member storage member = viewMember(msg.sender);
        require(systemOpen, "The system is not open for deposits");
        require(!member.hasDeposited, "You have already deposited");
        require(
            block.timestamp <= member.timeConstraint,
            "Time constraint exceeded"
        );

        member.depositAmount = msg.value;
        member.hasDeposited = true;
        poolBalance += msg.value;
        emit Deposit(msg.sender, msg.value);

        if (
            member.isOwner &&
            block.timestamp >= member.timeConstraint &&
            totalPayouts < poolBalance
        ) {
            uint256 ownerPayout = (poolBalance * totalMembers) /
                totalRequiredPayouts;
            if (totalPayouts + ownerPayout > poolBalance) {
                ownerPayout = poolBalance - totalPayouts;
                emit SavingsPoolComplete(totalPayouts + ownerPayout);
            }
            totalPayouts += ownerPayout;
            payable(msg.sender).transfer(ownerPayout);
            currentMonth++;
            for (uint256 i = 0; i < members.length; i++) {
                members[i].isOwner = false;
                members[i].hasDeposited = false;
            }
            members.push(
                Member(
                    msg.sender,
                    0,
                    block.timestamp + member.timeConstraint,
                    true,
                    false
                )
            );
            emit MemberAdded(msg.sender, member.timeConstraint);
        }
    }

    function viewMember(address _memberAddress)
        internal
        view
        returns (Member storage)
    {
        for (uint256 i = 0; i < members.length; i++) {
            if (members[i].memberAddress == _memberAddress) {
                return members[i];
            }
        }
        revert("Member not found");
    }

    function joinMember() external {
        members.push(Member(msg.sender, 0, block.timestamp, true, false));
        emit MemberAdded(msg.sender, block.timestamp);
        totalMembers++;
    }
}

