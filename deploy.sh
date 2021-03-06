#!/bin/bash

# 初始化参数
deployer="git-deployer";
source ./$deployer/config.sh;

# user=$(whoami);
gitStorageLen=${#gitServerAllPrefixes[@]};
for (( i=0; i < $gitStorageLen; i++  )); do
  if  [[ ${gitServerAllPrefixes[$i]} == $fetchSeverPrefix ]]; then
   localRepoServerPathPrefix=${gitServerAllPrefixes[$i]};
   # 以下下行实现在没有all远程别名的情况下将config.sh中的fetchServerPrefix设为默认的fetch-url;
   # 如果现已有all远程别名,还是改.git/config比较方便，毕竟这种情况不会经常发生。
   temp=${gitServerAllPrefixes[$i]};
   gitServerAllPrefixes[$i]=${gitServerAllPrefixes[0]};
   gitServerAllPrefixes[0]=$temp;
  fi
  echo This gitServerPrefixes will be mapped: ${gitServerAllPrefixes[$i]};
done
echo Alias 'all' branch will be master, when this script would be complated.


rootDir=$(realpath .);
echo 项目根目录: $rootDir;
repoName=$(basename $rootDir);
echo 正在测试的repo名: $repoName;
localRepoServerPath="$localRepoServerPathParent/$repoName.git";



# 定义函数judgeLatestCmd根据判断上一条命令的执行状态码,将尾随函数的第一个作为消息输出到stdoutput;
function judgeLatestCmd(){
  if [ $? -ne 0 ]; then
    echo $1
    if [[ $2 ]]; then
      $2;
    fi
    exit 1
  fi
}

function addMapIfCreated(){
  while [[ true ]]; do
    read created
    if [[ $created == 'yes' ]]; then
      # git remote set-url all --add $1/$repoName.git;
      gitHandleUrl $1/$repoName.git;
      break;
    elif [[ $created == 'no' ]]; then 
      echo 你应该想准备好空的远程仓库：$1/$repoName.git, 一会儿再来哟!
      exit 0
    fi
  done
}

function gitInitIfNoBranchAll(){
  if [[ -d '.git'  ]]; then
    if [[ $(git remote) && $(git remote | grep all) != 'all'  ]]; then
      echo "当前项目是git初始化过的, 并且其中没有映射　'all'";
      echo 请手动输入git命令完成部署。;
      exit 2
    fi
  elif [[  $(git remote | grep all) =~ all ]]; then
    echo "'all' 分支已经存在".
    continue;
  else
    git init;
  fi
}

function gitHandleUrl(){
  match=$(git remote -v | grep $1);
  if  [[ $1 =~ git@localhost\.*|git@127.0.0.1\.* ]]; then
    if [[ $(git remote -v | grep $1 ) != $1 ]]; then
      if [[ ! $match ]]; then
        if [[  $(git remote | grep '^all') ]]; then
          git remote set-url --add all $1;
        else
          git remote add all $fetchSeverPrefix/$repoName.git;
          git remote -v;
        fi;
      fi
    else
      echo "$1 已经在映射 'all' url队列中了";
    fi
  else
    if [[ $(git remote -v | grep $1 ) != $1 ]]; then
      if [[ ! $match ]]; then
        git remote set-url all --add $1;
      fi
    else
      echo "$1 已经在映射 'all'  url队列中了";
    fi
  fi
}





for (( i=0; i < $gitStorageLen; i++  )); do
  if  [[ ${gitServerAllPrefixes[$i]} =~ git@localhost\.*|git@127.0.0.1\.* ]]; then
    gitInitIfNoBranchAll;
    gitHandleUrl ${gitServerAllPrefixes[$i]}/$repoName.git;
    git remote -v | grep ${gitServerAllPrefixes[$i]};
  else
    echo -n "Is the uninitialized repository ${gitServerAllPrefixes[$i]}/$repoName.git ready?  [ yes / no ]:  "
    addMapIfCreated ${gitServerAllPrefixes[$i]};	
  fi
done

git remote -v

# 如果localRepoServerPath不存在,就创建本地git--bare库的;
if [ ! -d $localRepoServerPath ]; then

  su git -c "mkdir $localRepoServerPath"
  judgeLatestCmd '创建repo失败'
 
  sudo sh -c "cd $localRepoServerPath; git init --bare"
  judgeLatestCmd '初始化  repo server  失败'
  
  sudo sh -c "chown git:git $localRepoServerPath -R"
  judgeLatestCmd '将该repo的所属用户和组修改为 git:git 失败'
fi


# check remote url, if it is not in rule, remote it;
function deleteThisUrl(){
  while [[ true ]]; do
    read delete
    if [[ $delete == 'yes' ]]; then
      git remote set-url --delete all  $line;
      break;
    else
      break;
    fi
  done
}
  # remove repeat; 
  # remote uri去重
declare -a disMatched;
declare -a verboseUris;
declare -a uniqueUris;
uniqueLength=0;
verboseLength=0;
# for line in $(git remote -v | grep 'git (push)' | awk '{print $2}'); do
for line in $(git remote -v | grep ' (push)' | awk '{print $2}'); do
       for (( n=0; n <= $uniqueLength; n++)); do
        if [[ $line == ${uniqueUris[$n]} ]]; then
          verboseUris[$verboseLength]=$line;
          verboseLength=$verboseLength+1;
          echo -n added verboseUri: ${verboseUris[${#verboseUris[@]} - 1]};
        else
          uniqueUris[$uniqueLength]=$line;
          uniqueLenght=$uniqueLength+1;
          n=$n+1; #因为$uniqueUris数组多了一个成员，不加1就无限循环
          echo -n added uniqueUri: $line;
          continue;
        fi;
       done;
      break; # 当前git仓库前缀已经匹配上了，就不选后边的仓库循环名了
done;

for ((m=0; m < $verboseLength; m++)); do
   echo -n "Checked ${verboseUris[$verboseLenth]} is verbose, would you like to delte this one?  [ yes / no ]:  ";
   deleteThisUrl ${verboseUris[$m]};
done


for line in $(git remote -v | grep ' (push)' | awk '{print $2}'); do
  flag=false;
  for (( i=0; i < $gitStorageLen; i++  )); do
    if [[ "$line" =~ ^${gitServerAllPrefixes[$i]}* ]]; then
      flag=true;
      break;
    fi
  done;
  if [[ ! $flag == true  ]]; then
   echo $line;
   echo -n "Checked $line does not match any git storage uri prefix configued in ./config.sh , would you like to delete this one?  [ yes / no ]:  ";
   deleteThisUrl $line;
  fi
done;


function exitIfreadNoNeed(){
  while [[ true ]]; do
    read need
    if [[ $need == 'yes' ]]; then
      # git remote set-url all --add $1/$repoName.git;
      break;
    elif [[ $need == 'no' ]]; then
      echo 谢谢你的使用，后会有期！
      exit 0;
    fi
  done
}

# 设置 remote fetch url;


echo -n "要提交添加工作区修改，提交提交到暂存区，并推送到到映射　'all'　的所有远程 master 分支吗？  [ yes / no ]:   ";
exitIfreadNoNeed;
#　提交并推送到到映射　\'all\'　的所有远程 master 分支；
echo salt >> salt.txt; git add .; git commit -am `date +%s%N`; git push all master;

echo -n "要创建并切换到 'gh-pages'　分支，并推送到到映射　'gh-pages'　的所有远程 master 分支吗？  [ yes / no ]:   ";
exitIfreadNoNeed;
#  创建并切换到 \'gh-pages\'　分支; 提交并推送到到映射　\'all\'　的所有远程 \'gh-pages\' 分支；
git branch gh-pages;  git checkout gh-pages;
echo salt >> salt.txt; git add .; git commit -am `date +%s%N`;
git push all gh-pages;
git checkout master;
