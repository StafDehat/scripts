// ==UserScript==
// @name           LendingClub Note Analysis
// @version        1.1
// @author         Andrew Howard
// @include        *lendingclub.com/*
// @grant          GM_addStyle
// @description    Description
// ==/UserScript==


function annotateOriginalDetails() {

  var loanDetails, memberProfile, memberCredit;
  var monthlyPayment;
  var monthlySalary;
  var annualSalary;

  loanDetails   = document.getElementsByClassName("details-wrapper")[0];
  memberProfile = document.getElementsByClassName("details-wrapper")[1];
  memberCredit  = document.getElementsByClassName("details-wrapper")[2];


  //
  // Scrape the first paragraph
  leftHeads = loanDetails.getElementsByClassName("loan-details")[0].getElementsByTagName("th");
  leftVals  = loanDetails.getElementsByClassName("loan-details")[0].getElementsByTagName("td");
  for (x=0; x<leftHeads.length; x++) {
    header = leftHeads[x].textContent;
    if ( header === "Monthly Payment" ) {
      monthlyPayment = parseFloat(leftVals[x].textContent.replace(/[,$]/g, ''));
    }
  }
  rightHeads = loanDetails.getElementsByClassName("loan-details")[1].getElementsByTagName("th");
  rightVals  = loanDetails.getElementsByClassName("loan-details")[1].getElementsByTagName("td");
  for (x=0; x<rightHeads.length; x++) {
    header = rightHeads[x].textContent;
    if ( header === "Funding Received" ) {
      loanSize = parseFloat(rightVals[x].textContent.replace(/[,$]/g, ''));
    }
  }


  //
  // Scrape the second paragraph
  // Nothing useful in the left column
  rightHeads = memberProfile.getElementsByClassName("loan-details")[1].getElementsByTagName("th");
  rightVals  = memberProfile.getElementsByClassName("loan-details")[1].getElementsByTagName("td");
  for (x=0; x<rightHeads.length; x++) {
    header = rightHeads[x].textContent;
    if ( header === "Gross Income" ) {
      monthlySalary = parseFloat(rightVals[x].textContent.replace(/[,$]/g, ''));
    }
    else if ( header === "Debt-to-Income (DTI)" ) {
      debtToIncome = parseFloat(rightVals[x].textContent.replace(/[,$]/g, ''));
    }
  }
  annualSalary = monthlySalary * 12;


  //
  // Scrape the third paragraph
  // Scrape the left column
  leftHeads = memberCredit.getElementsByClassName("loan-details")[0].getElementsByTagName("th");
  leftVals  = memberCredit.getElementsByClassName("loan-details")[0].getElementsByTagName("td");
  for (x=0; x<leftHeads.length; x++) {
    header = leftHeads[x].textContent;
    if ( header === "Credit Score Range:" ) {
      creditScore = parseFloat(leftVals[x].textContent.replace(/[,$]/g, ''));
    }
    else if ( header === "Revolving Credit Balance" ) {
      totalDebt = parseFloat(leftVals[x].textContent.replace(/[,$]/g, ''));
    }
    else if ( header === "Revolving Line Utilization") {
      debtPercentUsed = parseFloat(leftVals[x].textContent.replace(/[,$]/g, ''));
    }
    else if ( header === "Accounts Now Delinquent" ) {
      numDelinquent = parseFloat(leftVals[x].textContent.replace(/[,$]/g, ''));
    }
  }
  // Scrape the right column
//  rightHeads = memberCredit.getElementsByClassName("loan-details")[1].getElementsByTagName("th");
//  rightVals  = memberCredit.getElementsByClassName("loan-details")[1].getElementsByTagName("td");
//  for (x=0; x<rightHeads.length; x++) {
//    header = rightHeads[x].textContent;
//    if ( header === "Accounts Now Delinquent" ) {
//      numDelinquent = parseFloat(rightVals[x].textContent.replace(/[,$]/g, ''));
//    }
//  }


  if ( totalDebt < monthlySalary * 2 &&
       loanSize < monthlySalary * 6 &&
       creditScore >= 700 &&
       monthlyPayment < monthlySalary / 10 &&
       debtPercentUsed < 50 &&
       numDelinquent == 0 ) {
     // Next Payment Date > (%Today + %7days)
     // No payment ERRORS
    conclusion="Safe loan";
  } else {
    conclusion="Unsafe - Do not buy";
  }


  htmlString ="<table>";
  htmlString+="<tr>";
  htmlString+="  <th>Variable</th>";
  htmlString+="  <th>Value</th>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>Monthly payment:</td>";
  htmlString+="  <td>" + monthlyPayment + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>Monthly Salary:</td>";
  htmlString+="  <td>" + monthlySalary + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>Annual Salary:</td>";
  htmlString+="  <td>" + annualSalary + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>Loan Size:</td>";
  htmlString+="  <td>" + loanSize + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>Debt-to-income:</td>";
  htmlString+="  <td>" + debtToIncome + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>Credit Score:</td>";
  htmlString+="  <td>" + creditScore + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>Debt (RCB):</td>";
  htmlString+="  <td>" + totalDebt + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>Debt % Used:</td>";
  htmlString+="  <td>" + debtPercentUsed + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>Delinquent Accts:</td>";
  htmlString+="  <td>" + numDelinquent + "</td>";
  htmlString+="</tr>";
  htmlString+="</table>";
  htmlString+="<table>";
  htmlString+="<tr>";
  htmlString+="  <th>Condition</th>";
  htmlString+="  <th>Pass/Fail</th>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>totalDebt < monthlySalary * 2:</td>";
  htmlString+="  <td>" + (totalDebt < monthlySalary * 2) + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>loanSize < monthlySalary * 6:</td>";
  htmlString+="  <td>" + (loanSize < monthlySalary * 6) + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>creditScore >= 700:</td>";
  htmlString+="  <td>" + (creditScore >= 700) + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>monthlyPayment < monthlySalary / 10:</td>";
  htmlString+="  <td>" + (monthlyPayment < monthlySalary / 10) + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>debtPercentUsed < 50:</td>";
  htmlString+="  <td>" + (debtPercentUsed < 50) + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>numDelinquent == 0:</td>";
  htmlString+="  <td>" + (numDelinquent == 0) + "</td>";
  htmlString+="</tr>";
  htmlString+="<tr>";
  htmlString+="  <td>Conclusion:</td>";
  htmlString+="  <td>" + conclusion + "</td>";
  htmlString+="</tr>";
  htmlString+="</table>";


  newDiv = document.createElement("div");
  newDiv.setAttribute("id", "analysis");
  newDiv.innerHTML = htmlString;

  tmp1 = document.getElementsByClassName("details-wrapper")[0];
  tmp2 = tmp1.parentNode;
  tmp2.insertBefore(newDiv, tmp1);
} // END annotateOriginalDetails()



//
// Set the price at which to sell new notes
function setSellPrice() {
  var newDiv, tmp1, tmp2;
  var htmlString;

  function updatePrices() {
    var loans, value, markup;
    loans = document.getElementById("loans-1").getElementsByTagName("tbody")[0].getElementsByTagName("tr");
    markup = parseFloat(document.getElementById("markup-amount").value);
    for (x=0; x<loans.length-1; x++) {
      value = parseFloat(loans[x].getElementsByClassName("outstanding-principal-accrued-interest")[0].textContent.replace(/[,$]/g, ''));
      loans[x].getElementsByClassName("asking-price")[0].value = Number(value * markup).toFixed(2);
    }
  }

  htmlString ="<input id='markup-amount' type='text' value='1.05' />";
  htmlString+="<input id='set-price-button' type='button' value='Reprice' />";

  newDiv = document.createElement("div");
  newDiv.setAttribute("align", "right");
  newDiv.innerHTML = htmlString;

  tmp1 = document.getElementById("submit-loans-for-sale");
  tmp2 = tmp1.parentNode;
  tmp2.insertBefore(newDiv, tmp1);

  document.getElementById("set-price-button").addEventListener('click', updatePrices, false );
} // END setSellPrice()


//
// Trim unsafe notes from buy screen
function setSearchParams() {
  document.getElementById("from_rate").selectedIndex = '6';
  document.getElementById("markup_dis_min").value = '-100';
  document.getElementById("markup_dis_max").value = '-1';
  document.getElementById("credit_score_min").value = '700';
  document.getElementById("credit_score_max").value = '850';
  document.getElementById("ytm_min").value = '10';
  document.getElementById("askp_max").value = '50';

} // END setSearchParams()


//
// Execution starts here
if ( document.location.pathname === "/foliofn/loanDetail.action" ) {
  window.addEventListener('load', annotateOriginalDetails(), false );
}
else if ( document.location.pathname === "/foliofn/selectLoansForSale.action" ||
          document.location.pathname === "/foliofn/selectNotesToReprice.action") {
  window.addEventListener('load', setSellPrice(), false );
}
else if ( document.location.pathname === "/foliofn/loanPerf.action" ) {
  
}
else if ( document.location.pathname === "/foliofn/tradingInventory.action" ) {
  window.addEventListener('load', setSearchParams(), false );
}

