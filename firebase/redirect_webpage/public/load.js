const path = location.pathname
let clipboardAppLink

function redirect() {
  const searchParam = new URLSearchParams(location.search)
  const isV2 = searchParam.get("state") === "v2"
  const search = isV2 ? encodeURI(btoa(location.search)) : location.search

  if (path.startsWith("/auth")) {
    clipboardAppLink = "clipboard://auth"
  } else {
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
