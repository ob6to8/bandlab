List todos from the terminal.

## Steps

1. Run `./bandlab-cli todos $ARGUMENTS`
2. Show the output to the user
3. If a specific todo ID is given (e.g. `t001`), also show full detail:
   `jq '.[] | select(.id == "t001")' org/todos.json`
