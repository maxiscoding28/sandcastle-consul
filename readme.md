# 🏰 Sandcastle Consul 🔑 📞
<p align="center">
<img src="consul.svg" alt="sand-castle" width=400 height=300>
<img src="sandcastle.png" alt="sand-castle" width=400 height=300>
</p>

## What Is This? 🤔
Sandcastle Consul is a directory of terraform files for quickly setting up a basc Consul cluster in an AWS cloud environment.
This repository was developed with support engineers mind. It can be useful for testing, experimenting, and troubleshooting in [Hashicorp Consul](https://www.consul.io/)

This infrastructure includes:
  - **Networking:**
    - [A VPC](https://docs.aws.amazon.com/vpc/latest/userguide/what-is-amazon-vpc.html)
    - [2 public subnets](https://docs.aws.amazon.com/vpc/latest/userguide/configure-subnets.html)
    - [An internet gateway](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Internet_Gateway.html)
    - [A route table](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Route_Tables.html)
  - **Security:**
    - [An IAM role](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles.html) associated with the two previously listed policies.
    - [An IAM instance profile](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_roles_use_switch-role-ec2_instance-profiles.html) for attaching the previously listed role to created EC2 instances.
    - [A security group](https://docs.aws.amazon.com/vpc/latest/userguide/vpc-security-groups.html) that allows access on [Consul ports](https://developer.hashicorp.com/consul/docs/install/ports).
- **Servers**
    - [A launch template for Consul nodes](https://docs.aws.amazon.com/autoscaling/ec2/userguide/launch-templates.html)
        - Each server instance generated from this template contains a userdata script [./startup.sh](./servers/startup.sh) that generates the neccessary configuration files for running Consul as well as some useful aliases.
    - [An autoscaling group](https://docs.aws.amazon.com/autoscaling/ec2/userguide/auto-scaling-groups.html)
    - [A launch template and autoscaling group for Express servers](https://docs.aws.amazon.com/autoscaling/ec2/userguide/launch-templates.html) (for service discovery)

## Okay, What Do I Need To Do To Set This Up? 😕
#### Prerequisties
- [Terraform](https://developer.hashicorp.com/terraform/downloads) installed
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed
- [jq](https://stedolan.github.io/jq/) installed
- A valid [Amazon EC2 Key Pair](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/create-key-pairs.html)
- An AWS account capable of creating all the required resources
- A valid [Consul Enterprise license](https://www.hashicorp.com/products/Consul/pricing)

## Got It, How Do I Make This Work? 🔧
#### 1. Clone the Repostiory onto your local machine and `cd` into the root directory
```
git clone git@github.com:maxiscoding28/sandcastle-consul.git && cd sandcastle-consul
```

#### 2. Confirm that you have valid AWS credentials to provision AWS resources.
```
aws sts get-caller-identity
```

#### 3. Add the AWS credential values as variables for terraform (along with your local IP).
```
echo "aws_account_id = \"$(aws sts get-caller-identity \
    --query 'Account' --output text)\"" \
    >> ./security/main.tfvars

echo "aws_role_arn = \"$(aws sts get-caller-identity \
    --query 'Arn' | awk -F/ '{print $2}')\"" \
    >> ./security/main.tfvars

echo "local_ip = \"$(curl -s 'https://api.ipify.org?format=json' \
    | jq -r '.ip')/32\"" \
    >> ./security/main.tfvars
```

#### 4. Add your Consul enterprise license to a new file in the `servers/` directory called `build.pkrvars.hcl`
```
CONSUL_LICENSE="<YOUR_CONSUL_LICENSE_GOES_HERE>"
```
```
echo "consul_license = \"$CONSUL_LICENSE\"" >> ./servers/main.tfvars
```

#### 5. Add the name of your ec2 key-pair to a new file in the `servers/` directory called `main.tfvars`
```
EC2_KEY_PAIR_NAME="<YOUR_EC2_KEY_PAIR_NAME_GOES_HERE>"
```
```
echo "ssh_key_name = \"$EC2_KEY_PAIR_NAME\"" >> ./servers/main.tfvars
```

#### 6. `cd` into the the `network/` directory, initialize terraform and create the network infrastructure. 
```
cd network/ && terraform init && terraform apply
```

#### 7. `cd` in to the `security/` directory, initialize terraform and create the security infrastructure.
```
cd ../security && terraform init && terraform apply -var-file=main.tfvars
```

#### 9. `cd` into the `servers/` directory, initialize terraform and create the servers infrastructure
```
cd ../servers && terraform init && terraform apply -var-file=main.tfvars
```

## Phew, Okay What Can I Do Now? 😓
- Grab the list of created servers
```
aws ec2 describe-instances \
--filters Name=instance-state-name,Values=running \
--query '[Reservations[].Instances[][Tags[?Key==`Name`].Value|[0], InstanceId, PublicDnsName]]' \
--output table --no-cli-pager
```
- Shell in as the Consul user
```
ssh -i $PATH_TO_YOUR_SSH_KEY -A consulsh@$EC2_ADDRESS
```
- Run consul members and list-peers
```
consul members && consul operator raft list-peers
```
🎉 You are up and running! 
- 📈 Scale up or down the number of servers in your ASG using [var.server_count](./servers/main.tf#L22-L28)
- 🧑‍💻 Hack as needed to make it work for your use case. 
- ⭐️ PRs and issues are welcome.

## How do I Destroy My Sandcastles? ☠️
- Once the `network/` and `security/` infrastructure is created I haven't needed to destroy these very often. Usually I am only making small changes to this infrastructure that can be modified with a `terraform apply`

- For `servers/`, you can create and destroy servers at will by re-running `terraform apply -var-file=main.tfvars` and adjusting the `server_count` variable.

- If you decide to destroy everything, I find that doing it in reverse order to the order that it was initially created gives you the highest likelihood of not hitting any issues that require you to go into the AWS console or CLI to delete things manually.
```
cd ./servers && terraform destroy -var-file=main.tfvars
cd .. && cd ./security && terraform destroy -var-file=main.tfvars
cd .. && cd ./network && terraform destroy && cd ..
```

- To clear out terraform state (in order to reinitialize) run these commands:
```
find . -type f -name "terraform.tfstate" -delete
find . -type f -name "terraform.tfstate.backup" -delete
find . -type f -name ".terraform.lock.hcl" -delete
find . -type d -name ".terraform" -exec rm -rf {} +
find . -type f -name "main.tfvars" -delete
```
