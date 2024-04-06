rm -rf ../amend

jit init ../amend

cd ../amend

for msg in one two three ; do
  echo "$msg" > file.txt
  jit add .
  jit commit --message "$msg"
done
