// Package main is the setup-go-lint smoke's fixture: one dependency, so the
// module cache has something to hold, and nothing for the linters to report.
package main

import (
	"fmt"

	"github.com/google/go-cmp/cmp"
)

func main() {
	fmt.Println(cmp.Equal([]int{1, 2}, []int{1, 2}))
}
