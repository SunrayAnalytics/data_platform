# Configuration file for the Sphinx documentation builder.
#
# For the full list of built-in configuration values, see the documentation:
# https://www.sphinx-doc.org/en/master/usage/configuration.html

# -- Project information -----------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#project-information

project = "Sunray Data Platform"
copyright = "2024, Sunray Analytics Ltd"
author = "Hans Peter"
release = "1.13"

import os.path

from dotenv import load_dotenv

load_dotenv()
import urllib.request
import pathlib
import sys

sys.path.insert(0, pathlib.Path(__file__).parents[2].resolve().as_posix())

# -- General configuration ---------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#general-configuration

extensions = [
    "sphinxcontrib.plantuml",
    "sphinx.ext.autodoc",
    "sphinx.ext.autosummary",
]

plantuml_jarfile = f"{os.path.dirname(__file__)}/plantuml-mit-1.2024.7.jar"
if not os.path.exists(plantuml_jarfile):
    print("Could not find plantuml jar downloading...")
    local_filename, headers = urllib.request.urlretrieve(
        "https://github.com/plantuml/plantuml/releases/download/v1.2024.7/plantuml-mit-1.2024.7.jar",
        filename=plantuml_jarfile,
    )

plantuml = f"java -jar {plantuml_jarfile}"


templates_path = ["_templates"]
exclude_patterns = ["_build", "Thumbs.db", ".DS_Store"]


# -- Options for HTML output -------------------------------------------------
# https://www.sphinx-doc.org/en/master/usage/configuration.html#options-for-html-output

html_theme = "alabaster"
html_static_path = ["_static"]
