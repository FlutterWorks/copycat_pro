function setError(code, desc) {
  setTimeout(() => {
    document.querySelector("#msg").innerHTML = `
    <div>
    <p>Error Occurred</p>
    <p>Code: ${code}</p>
    <p>${desc}</p>
    </div>
    `
  }, 1000)
}

function redirect() {
  const searchParam = new URLSearchParams(location.search)

  const isError = searchParam.get("error")

  if (isError) {
    const errorCode = searchParam.get("error_code")
    const errorDesc = searchParam.get("error_description")
    setError(errorCode, errorDesc)
    return;
  }


  const isV2 = searchParam.get("state") === "v2"
  const search = isV2 ? encodeURI(btoa(location.search)) : location.search

  const path = location.pathname
  let clipboardAppLink = null

  if (path.startsWith("/auth")) {
    clipboardAppLink = "clipboard://auth"
  } else if (path.startsWith("/reset-password")) {
    clipboardAppLink = "clipboard://reset-password"
  }
  else {
    clipboardAppLink = "clipboard://drive-connect"
  }

  clipboardAppLink = `${clipboardAppLink}/${search}`
  location.href = clipboardAppLink

  setTimeout(() => {
    document.querySelector("#msg").innerHTML = `
    <div>
    <p>Done! You may now close this window.</p>
    <p>Didn't opened the app yet? <a style="color: #7469B6" href="${clipboardAppLink}">Click here</a></p>
    </div>
    `
  }, 2000)
}

window.onload = redirect
