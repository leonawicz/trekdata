
<!-- README.md is generated from README.Rmd. Please edit that file -->

# trekdata

**Author:** [Matthew Leonawicz](https://leonawicz.github.io/blog/)
<a href="https://orcid.org/0000-0001-9452-2771" target="orcid.widget">
<image class="orcid" src="https://members.orcid.org/sites/default/files/vector_iD_icon.svg" height="16"></a>
<br/> **License:** [MIT](https://opensource.org/licenses/MIT)<br/>

[![Travis-CI Build
Status](https://travis-ci.org/leonawicz/trekdata.svg?branch=master)](https://travis-ci.org/leonawicz/trekdata)
[![AppVeyor Build
Status](https://ci.appveyor.com/api/projects/status/github/leonawicz/trekdata?branch=master&svg=true)](https://ci.appveyor.com/project/leonawicz/trekdata)
[![Coverage
Status](https://img.shields.io/codecov/c/github/leonawicz/trekdata/master.svg)](https://codecov.io/github/leonawicz/trekdata?branch=master)

The `trekdata` package assists with extracting and curating datasets
that appear in the `rtrek` package. The scripts associated with this
preparation from source data would typically appear in the `rtrek`
repository `data-raw` folder.

However, since the datasets are derived from varied sources and require
a number of custom functions to facilitate all of the preprocessing, it
would make for an unwieldy collection of scripts in the `data-raw`
folder. Instead, all that work is packaged here to simplify the code
contained in `rtrek/data-raw`.

## Installation

You can install the development version of `trekdata` from GitHub with:

``` r
# install.packages("remotes")
remotes::install_github("leonawicz/trekdata")
```
