const axios = require('axios');
const pkg = require('./package.json');

module.exports = axios.create({
  headers: {'User-Agent': `jenkins-wiki-exporter/${pkg.version}`},
});

module.exports.catchAxiosError = (error) => {
  if (error.response) {
    // The request was made and the server responded with a status code
    // that falls out of the range of 2xx
    console.log(error.response.data);
    console.log(error.response.status);
    console.log(error.response.headers);
    throw new Error("Bad request")
  }
  // Something happened in setting up the request that triggered an Error
  throw error;
}
