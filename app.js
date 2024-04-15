//Before Git Push Heroku Master
//1. Remove encryption secret x 1
//2. Remove mySQL database environemnt variables x 4
//3. Change timing x 2 from 580 to 58 and 590 to 59

var express         = require("express"),
    app             = express(),
    bodyParser      = require("body-parser"),
    axios           = require("axios"),
    passport        = require("passport"),
    LocalStrategy   = require("passport-local"),
    http            = require("http"),
    mysql           = require("mysql"),
    bcrypt          = require("bcrypt"),
    session         = require("express-session");
    
app.use(bodyParser.urlencoded({extended: true}));
app.use(express.static(__dirname + "/public"));

app.use(session({
    secret: '' || process.env.ENCRYPTION_SECRET,
    resave: false,
    saveUninitialized: false
}));

app.use(passport.initialize());
app.use(passport.session());

passport.serializeUser(function(username, done) {
   done(null, username);
});
passport.deserializeUser(function(username, done) {
   done(null, username);
});

function isLoggedIn(req, res, next) {
    if(req.isAuthenticated()){
        return next();
    }
    res.redirect("/");
}

passport.use(new LocalStrategy(
    function(username, password, done) {
        connection.query('SELECT password FROM user WHERE username = ?', [username], function(err, results, fields) {
            if (err) {
                return done(err);
            } else {
                if (results.length === 0) {
                    return done(null, false);
                } else {
                    bcrypt.compare(password, results[0].password.toString(), function(err, response) {
                        if (err) {
                            console.log(err);
                        } else {
                            if (response === true) {
                                return done(null, username);
                            } else {
                                done(null, false);
                            }
                        }
                    });
                }
            }
        });
    }
));



var connection = mysql.createConnection({
    host     : '' || process.env.DATABASE_HOST,
    user     : '' || process.env.DATABASE_USER,
    password : '' || process.env.DATABASE_PASSWORD,
    database : '' || process.env.DATABASE_NAME
});

//To force MySQL to keep the connection alive
setInterval(function () {
    connection.query('SELECT 1');
}, 5000);



//These will pass the variable currentUser to every .ejs file without me having
//to pass them to each and every one of them, so all the routes will have these
app.use(function(req, res, next){
    res.locals.currentUser = req.user;
    next();
});

app.use(function(req, res, next){
    res.locals.message = "";
    next();
});

app.use(function(req, res, next){
    res.locals.page = "landing";
    next();
});


//Routes
//-------------------------------------------
var wcurrency_code = 'USD';
var wexchange_code = 'EUR';
var wrates_or_prices = 'Rates';
var wacctTotal = 0;
var wstmtDate = "";

//root route
app.get("/", function(req, res){
    res.render("landing.ejs");
});



app.get("/rates", function(req, res){
    connection.query('CALL sp_currency_board(' + "'" + wcurrency_code + "','" + wrates_or_prices + "'" + ')', function(err, resultsCurrBoard, fields) {
        if (err) {
            console.log(err);
        } else {
            res.render("rates.ejs", {currency_code: wcurrency_code, rates_or_prices: wrates_or_prices, data: resultsCurrBoard[0], page: "rates"});
        }
    });

});





app.post("/rates", function(req, res){
    wcurrency_code = 'USD';
    wrates_or_prices = 'Rates';

    if(req.body.curCode){
        wcurrency_code = req.body.curCode;
    }
    if(req.body.rtsPrs){
        wrates_or_prices = req.body.rtsPrs;
    }
    
    res.redirect("/rates");

});





app.get("/graphs", function(req, res){
    connection.query('CALL sp_candle_stick(' + "'" + wcurrency_code + "','" + wexchange_code + "','" + wrates_or_prices + "'" + ')', function(err, resultsCandleStick, fieldsCandleStick) {
        if (err) {
            console.log(err);
        } else {
            connection.query('CALL sp_currency_pairs_hourly(' + "'" + wcurrency_code + "','" + wexchange_code + "','" + wrates_or_prices + "'" + ')', function(err, resultsHourly, fieldsHourly) {
                if (err) {
                    console.log(err);
                } else {
                    connection.query('CALL sp_currency_pairs_daily(' + "'" + wcurrency_code + "','" + wexchange_code + "','" + wrates_or_prices + "'" + ')', function(err, resultsDaily, fieldsDaily) {
                        if (err) {
                            console.log(err);
                        } else {
                            connection.query('CALL sp_past_performance_hourly_graph(' + "'" + wcurrency_code + "','" + 72 + "'" + ')', function(err, resultsPastPerfHourly, fieldsPastPerfHourly) {
                                if (err) {
                                    console.log(err);
                                } else {
                                    connection.query('CALL sp_past_performance_table(' + "'" + wcurrency_code + "'" + ')', function(err, resultsPastPerfTable, fieldsPastPerfTable) {
                                        if (err) {
                                            console.log(err);
                                        } else {
                            
                                            var wdata = [];
                                            var wcandleStickChartData = "";
                                            var whourlyChartData = "";
                                            var wdailyChartData = "";
                                            var wpastPerfHourlyChartData = "";
                                            var wdataPastPerfTable = [];
                                            var wresultsPastPerfTable1s = [];
                                            var wresultsPastPerfTable2s = [];
                                            var wresultsPastPerfTable3s = [];
                                            var wresultsPastPerfTable4s = [];
                                            var wresultsPastPerfTable5s = [];
                                            var wresultsPastPerfTable6s = [];
                                            var wresultsPastPerfTable1a = [];
                                            var wresultsPastPerfTable2a = [];
                                            var wresultsPastPerfTable3a = [];
                                            var wresultsPastPerfTable4a = [];
                                            var wresultsPastPerfTable5a = [];
                                            var wresultsPastPerfTable6a = [];                                           
                                            var wresultsPastPerfTable1 = [];
                                            var wresultsPastPerfTable2 = [];
                                            var wresultsPastPerfTable3 = [];
                                            var wresultsPastPerfTable4 = [];
                                            var wresultsPastPerfTable5 = [];
                                            var wresultsPastPerfTable6 = [];
                                            
                                            
                                            for (var i = 0; i < resultsCandleStick[0].length; i++) {
                                                wcandleStickChartData += '{"date": ' + (new Date(resultsCandleStick[0][i].date) - (new Date('1970-01-01'))) / 86400000 + ', "open": ' + resultsCandleStick[0][i].open + ', "high": ' + resultsCandleStick[0][i].max + ', "low": ' + resultsCandleStick[0][i].min + ', "close": ' + resultsCandleStick[0][i].close + '};';
                                            }
                                            wcandleStickChartData = wcandleStickChartData.substring(0, wcandleStickChartData.length - 1);
                
                                            wdata.push(wcandleStickChartData);
                
                
                
                
                                            for (var i = 0; i < resultsHourly[0].length; i++) {
                                                whourlyChartData += '[' + (new Date(resultsHourly[0][i].date_hour) - (new Date('1970-01-01'))) / 3600000 + ', ' + resultsHourly[0][i].mid + ']:';
                                            }
                                            whourlyChartData = whourlyChartData.substring(0, whourlyChartData.length - 1);
                
                                            wdata.push(whourlyChartData);
                
                
                
                
                                            for (var i = 0; i < resultsDaily[0].length; i++) {
                                                wdailyChartData += '[' + (new Date(resultsDaily[0][i].date) - (new Date('1970-01-01'))) / 86400000 + ', ' + resultsDaily[0][i].mid + ']:';
                                            }
                                            wdailyChartData = wdailyChartData.substring(0, wdailyChartData.length - 1);
                
                                            wdata.push(wdailyChartData);
                
        
        
        
                                            for (var k = 0; k < 4; k++) {
                                                var cd = "";
                                                if (k == 0) {
                                                    for (var i = 0; i < resultsPastPerfHourly[0].length; i++) {
                                                        if (cd == "") {
                                                            cd = resultsPastPerfHourly[0][i].currency_id;
                                                            wpastPerfHourlyChartData += resultsPastPerfHourly[0][i].currency_id + '$';
                                                        } else if (cd != resultsPastPerfHourly[0][i].currency_id) {
                                                            cd = resultsPastPerfHourly[0][i].currency_id;
                                                            wpastPerfHourlyChartData = wpastPerfHourlyChartData.substring(0, wpastPerfHourlyChartData.length - 1);
                                                            wpastPerfHourlyChartData += '~' + resultsPastPerfHourly[0][i].currency_id + '$';
                                                        }
                                                        wpastPerfHourlyChartData += '[' + (new Date(resultsPastPerfHourly[0][i].date_hour) - (new Date('1970-01-01'))) / 3600000 + ', ' + resultsPastPerfHourly[0][i].total + ']:';
                                                    }
                                                    wpastPerfHourlyChartData = wpastPerfHourlyChartData.substring(0, wpastPerfHourlyChartData.length - 1);
                                                    wpastPerfHourlyChartData += '^';
                                                } else if (k == 1) {
                                                    for (var i = 0; i < resultsPastPerfHourly[0].length; i++) {
                                                        if (cd == "") {
                                                            cd = resultsPastPerfHourly[0][i].currency_id;
                                                            wpastPerfHourlyChartData += resultsPastPerfHourly[0][i].currency_id + '$';
                                                        } else if (cd != resultsPastPerfHourly[0][i].currency_id) {
                                                            cd = resultsPastPerfHourly[0][i].currency_id;
                                                            wpastPerfHourlyChartData = wpastPerfHourlyChartData.substring(0, wpastPerfHourlyChartData.length - 1);
                                                            wpastPerfHourlyChartData += '~' + resultsPastPerfHourly[0][i].currency_id + '$';
                                                        }
                                                        wpastPerfHourlyChartData += '[' + (new Date(resultsPastPerfHourly[0][i].date_hour) - (new Date('1970-01-01'))) / 3600000 + ', ' + resultsPastPerfHourly[0][i].total_amp_ten + ']:';
                                                    }
                                                    wpastPerfHourlyChartData = wpastPerfHourlyChartData.substring(0, wpastPerfHourlyChartData.length - 1);
                                                    wpastPerfHourlyChartData += '^';
                                                } else if (k == 2) {
                                                    for (var i = 0; i < resultsPastPerfHourly[0].length; i++) {
                                                        if (cd == "") {
                                                            cd = resultsPastPerfHourly[0][i].currency_id;
                                                            wpastPerfHourlyChartData += resultsPastPerfHourly[0][i].currency_id + '$';
                                                        } else if (cd != resultsPastPerfHourly[0][i].currency_id) {
                                                            cd = resultsPastPerfHourly[0][i].currency_id;
                                                            wpastPerfHourlyChartData = wpastPerfHourlyChartData.substring(0, wpastPerfHourlyChartData.length - 1);
                                                            wpastPerfHourlyChartData += '~' + resultsPastPerfHourly[0][i].currency_id + '$';
                                                        }
                                                        wpastPerfHourlyChartData += '[' + (new Date(resultsPastPerfHourly[0][i].date_hour) - (new Date('1970-01-01'))) / 3600000 + ', ' + resultsPastPerfHourly[0][i].total_amp_fifty + ']:';
                                                    }
                                                    wpastPerfHourlyChartData = wpastPerfHourlyChartData.substring(0, wpastPerfHourlyChartData.length - 1);
                                                    wpastPerfHourlyChartData += '^';
                                                } else {
                                                        for (var i = 0; i < resultsPastPerfHourly[0].length; i++) {
                                                        if (cd == "") {
                                                            cd = resultsPastPerfHourly[0][i].currency_id;
                                                            wpastPerfHourlyChartData += resultsPastPerfHourly[0][i].currency_id + '$';
                                                        } else if (cd != resultsPastPerfHourly[0][i].currency_id) {
                                                            cd = resultsPastPerfHourly[0][i].currency_id;
                                                            wpastPerfHourlyChartData = wpastPerfHourlyChartData.substring(0, wpastPerfHourlyChartData.length - 1);
                                                            wpastPerfHourlyChartData += '~' + resultsPastPerfHourly[0][i].currency_id + '$';
                                                        }
                                                        wpastPerfHourlyChartData += '[' + (new Date(resultsPastPerfHourly[0][i].date_hour) - (new Date('1970-01-01'))) / 3600000 + ', ' + resultsPastPerfHourly[0][i].total_amp_hundred + ']:';
                                                    }
                                                    wpastPerfHourlyChartData = wpastPerfHourlyChartData.substring(0, wpastPerfHourlyChartData.length - 1);
                                                }
                                                    
                                            }
                
                                            wdata.push(wpastPerfHourlyChartData);
          
          
        
        
                                            for (var i = 0; i < resultsPastPerfTable[0].length; i++) {
                                                wresultsPastPerfTable1a.push(resultsPastPerfTable[0][i].exchange);
                                                wresultsPastPerfTable2a.push(resultsPastPerfTable[0][i].exchange);
                                                wresultsPastPerfTable3a.push(resultsPastPerfTable[0][i].exchange);
                                                wresultsPastPerfTable4a.push(resultsPastPerfTable[0][i].exchange);
                                                wresultsPastPerfTable5a.push(resultsPastPerfTable[0][i].exchange);
                                                wresultsPastPerfTable6a.push(resultsPastPerfTable[0][i].exchange);
                                                
                                                wresultsPastPerfTable1a.push(((wrates_or_prices == 'Rates') ? resultsPastPerfTable[0][i].diff3day : (resultsPastPerfTable[0][i].diff3day) * -1));
                                                wresultsPastPerfTable2a.push(((wrates_or_prices == 'Rates') ? resultsPastPerfTable[0][i].diff1week : (resultsPastPerfTable[0][i].diff1week) * -1));
                                                wresultsPastPerfTable3a.push(((wrates_or_prices == 'Rates') ? resultsPastPerfTable[0][i].diff1month : (resultsPastPerfTable[0][i].diff1month) * -1));
                                                wresultsPastPerfTable4a.push(((wrates_or_prices == 'Rates') ? resultsPastPerfTable[0][i].diff3month : (resultsPastPerfTable[0][i].diff3month) * -1));
                                                wresultsPastPerfTable5a.push(((wrates_or_prices == 'Rates') ? resultsPastPerfTable[0][i].diff1year : (resultsPastPerfTable[0][i].diff1year) * -1));
                                                wresultsPastPerfTable6a.push(((wrates_or_prices == 'Rates') ? resultsPastPerfTable[0][i].diffmax : (resultsPastPerfTable[0][i].diffmax) * -1));

                                                wresultsPastPerfTable1s.push(wresultsPastPerfTable1a);
                                                wresultsPastPerfTable2s.push(wresultsPastPerfTable2a);
                                                wresultsPastPerfTable3s.push(wresultsPastPerfTable3a);
                                                wresultsPastPerfTable4s.push(wresultsPastPerfTable4a);
                                                wresultsPastPerfTable5s.push(wresultsPastPerfTable5a);
                                                wresultsPastPerfTable6s.push(wresultsPastPerfTable6a);

                                                wresultsPastPerfTable1a = [];
                                                wresultsPastPerfTable2a = [];
                                                wresultsPastPerfTable3a = [];
                                                wresultsPastPerfTable4a = [];
                                                wresultsPastPerfTable5a = [];
                                                wresultsPastPerfTable6a = [];
                                            }



                                            wresultsPastPerfTable1s.sort(function(a, b) { if (a[1] === b[1]) { return 0; } else { return (a[1] < b[1]) ? 1 : -1; } });
                                            wresultsPastPerfTable2s.sort(function(a, b) { if (a[1] === b[1]) { return 0; } else { return (a[1] < b[1]) ? 1 : -1; } });
                                            wresultsPastPerfTable3s.sort(function(a, b) { if (a[1] === b[1]) { return 0; } else { return (a[1] < b[1]) ? 1 : -1; } });
                                            wresultsPastPerfTable4s.sort(function(a, b) { if (a[1] === b[1]) { return 0; } else { return (a[1] < b[1]) ? 1 : -1; } });
                                            wresultsPastPerfTable5s.sort(function(a, b) { if (a[1] === b[1]) { return 0; } else { return (a[1] < b[1]) ? 1 : -1; } });
                                            wresultsPastPerfTable6s.sort(function(a, b) { if (a[1] === b[1]) { return 0; } else { return (a[1] < b[1]) ? 1 : -1; } });



                                            for (var i = 0; i < resultsPastPerfTable[0].length; i++) {
                                                wresultsPastPerfTable1.push({exchange: wresultsPastPerfTable1s[i][0], diff: parseFloat(wresultsPastPerfTable1s[i][1]).toFixed(2)});
                                                wresultsPastPerfTable2.push({exchange: wresultsPastPerfTable2s[i][0], diff: parseFloat(wresultsPastPerfTable2s[i][1]).toFixed(2)});
                                                wresultsPastPerfTable3.push({exchange: wresultsPastPerfTable3s[i][0], diff: parseFloat(wresultsPastPerfTable3s[i][1]).toFixed(2)});
                                                wresultsPastPerfTable4.push({exchange: wresultsPastPerfTable4s[i][0], diff: parseFloat(wresultsPastPerfTable4s[i][1]).toFixed(2)});
                                                wresultsPastPerfTable5.push({exchange: wresultsPastPerfTable5s[i][0], diff: parseFloat(wresultsPastPerfTable5s[i][1]).toFixed(2)});
                                                wresultsPastPerfTable6.push({exchange: wresultsPastPerfTable6s[i][0], diff: parseFloat(wresultsPastPerfTable6s[i][1]).toFixed(2)});
                                            }
                                            


                                            wdataPastPerfTable.push(wresultsPastPerfTable1);
                                            wdataPastPerfTable.push(wresultsPastPerfTable2);
                                            wdataPastPerfTable.push(wresultsPastPerfTable3);
                                            wdataPastPerfTable.push(wresultsPastPerfTable4);
                                            wdataPastPerfTable.push(wresultsPastPerfTable5);
                                            wdataPastPerfTable.push(wresultsPastPerfTable6);

                                            wdata.push(wdataPastPerfTable);

        
        
                
                                            res.render("graphs.ejs", {currency_code: wcurrency_code, exchange_code: wexchange_code, rates_or_prices: wrates_or_prices, data: wdata, page: "graphs"});

                                        }
                                    });

                                }
                            });

                        }
                    });
                }
            });
        }
    });

});



app.post("/graphs", function(req, res){
    wcurrency_code = 'USD';
    wrates_or_prices = 'Rates';

    if(req.body.curCode){
        wcurrency_code = req.body.curCode;
    }
    if(req.body.curCode){
        wexchange_code = req.body.excCode;
    }
    if(req.body.rtsPrs){
        wrates_or_prices = req.body.rtsPrs;
    }
    
    res.redirect("/graphs");

});





//Main Page for Profile
app.get("/trading", isLoggedIn, function(req, res){
    var wbase_currency_code = "";
    var wtotal = 0;
    connection.query('CALL sp_trading_board(' + "'" + req.user + "','" + wrates_or_prices + "'" + ')', function(err, results, fields) {
        if (err) {
            console.log(err);
        } else {
            for(var i = 0; i <  results[0].length; i++) { 
                
                if (results[0][i].graph > 0) {
                    wtotal += results[0][i].value_in_base_currency;    
                } else {
                    wtotal += results[0][i].units;
                }
                
                
                if (results[0][i].graph == 0) {
                    wbase_currency_code = results[0][i].code;
                }
                if (results[0][i].units) {
                    results[0][i].units = parseFloat(results[0][i].units).toFixed(2).toString() + ' ' + results[0][i].code;
                }

            }
            wtotal = parseFloat(wtotal).toFixed(2).toString();
            res.render("trading.ejs", {rates_or_prices: wrates_or_prices, currency_code: wbase_currency_code, total: wtotal, data: results[0], page: "trading"});
        }
    });
    
});



app.post("/trading", function(req, res){
    wrates_or_prices = 'Rates';

    if(req.body.rtsPrs){
        wrates_or_prices = req.body.rtsPrs;
    }
    
    res.redirect("/trading");

});


 


app.post("/trade", function(req, res){
    wrates_or_prices = 'Rates';

    if(req.body.rtsPrs){
        wrates_or_prices = req.body.rtsPrs;
    }

    connection.query('CALL sp_trade(' + "'" + req.user + "','" + req.body.qCurCodeSell + "','" + req.body.qUnitsSell + "','" + req.body.qCurCodeBuy + "'" + ')', function(err, results, fields) {
        if (err) {
            console.log(err);
        } else {
            res.redirect("/trading");
        }
    });

});




app.get("/account", isLoggedIn, function(req, res){
    connection.query('CALL sp_account_balance_hourly(' + "'" + req.user + "'," + 'CURRENT_TIMESTAMP(), -24)', function(err, resultsHourly, fieldsHourly) {
        if (err) {
            console.log(err);
        } else {
            connection.query('CALL sp_account_balance_daily(' + "'" + req.user + "'," + 'CURDATE(), -30)', function(err, resultsDaily, fieldsDaily) {
                if (err) {
                    console.log(err);
                } else {
                    connection.query('CALL sp_trade_history(' + "'" + req.user + "'," + 'CURDATE(), "EOMonth", "Desc")', function(err, resultsMonthlyTrades, fieldsMonthlyTrades) {
                        if (err) {
                            console.log(err);
                        } else {
                            connection.query('CALL sp_statements_monthly_links(' + "'" + req.user + "'" + ')', function(err, resultsStatementsMonthlyLinks, fieldsStatementsMonthlyLinks) {
                                if (err) {
                                    console.log(err);
                                } else {
                                    connection.query('CALL sp_statements_quarterly_links(' + "'" + req.user + "'" + ')', function(err, resultsStatementsQuarterlyLinks, fieldsStatementsQuarterlyLinks) {
                                        if (err) {
                                            console.log(err);
                                        } else {
                                            connection.query('CALL sp_statements_yearly_links(' + "'" + req.user + "'" + ')', function(err, resultsStatementsYearlyLinks, fieldsStatementsYearlyLinks) {
                                                if (err) {
                                                    console.log(err);
                                                } else {
                   
                    
                                                    var wdata = [];
                                                    var whourlyChartData = "";
                                                    var wdailyChartData = "";
                                                    
                                
                                                    for (var i = 0; i < resultsHourly[0].length; i++) {
                                                        whourlyChartData += '[' + (new Date(resultsHourly[0][i].date_hour) - (new Date('1970-01-01'))) / 3600000 + ', ' + resultsHourly[0][i].total + ']:';
                                                    }
                                                    whourlyChartData = whourlyChartData.substring(0, whourlyChartData.length - 1);
                                
                                                    wdata.push(whourlyChartData);
                                
                                
                                
                                
                                                    for (var i = 0; i < resultsDaily[0].length; i++) {
                                                        wdailyChartData += '[' + (new Date(resultsDaily[0][i].date) - (new Date('1970-01-01'))) / 86400000 + ', ' + resultsDaily[0][i].total + ']:';
                                                    }
                                                    wdailyChartData = wdailyChartData.substring(0, wdailyChartData.length - 1);
                                
                                                    wdata.push(wdailyChartData);
                                
                                
                                
                                
                                                    wdata.push(resultsMonthlyTrades[0]);
                                                    wdata.push(resultsStatementsMonthlyLinks[0]);
                                                    wdata.push(resultsStatementsQuarterlyLinks[0]);
                                                    wdata.push(resultsStatementsYearlyLinks[0]);
                        
                        
                                                    res.render("account.ejs", {currency_code: wcurrency_code, acctTotal: wacctTotal, data: wdata, page: "account"});

                                                }
                                            });
                                        }
                                    });
                                }
                            });
                        }
                    });
                }
            });
        }
    });
                   
});



app.post("/account", function(req, res){
    if(req.body.curCode){
        wcurrency_code = req.body.curCode;
    }
    if(req.body.acctTotal){
        wacctTotal = req.body.acctTotal;
    }
    
    res.redirect("/account");

});



//Statements

app.get("/monthlyStatement", isLoggedIn, function(req, res){
    connection.query('CALL sp_account_balance_daily(' + "'" + req.user + "','" + wstmtDate + "'" + ',"EOMonth")', function(err, resultsAccountBalanceDaily, fieldsAccountBalanceDaily) {
        if (err) {
            console.log(err);
        } else {
            connection.query('CALL sp_trade_history(' + "'" + req.user + "','" + wstmtDate + "'" + ',"EOMonth","Asc")', function(err, resultsMonthlyTrades, fieldsMonthlyTrades) {
                if (err) {
                    console.log(err);
                } else {
                    var wdata = [];
        
                    wdata.push(resultsAccountBalanceDaily[0]);
                    wdata.push(resultsMonthlyTrades[0]);
        
        
                    res.render("monthlyStatement.ejs", {currency_code: wcurrency_code, data: wdata, page: "monthlyStatement"});
                }
            });
        }
    });
});

app.post("/monthlyStatement", function(req, res){
    if(req.body.stmtDate){
        wstmtDate = req.body.stmtDate;
    }
    res.redirect("/monthlyStatement");
});




app.get("/quarterlyStatement", isLoggedIn, function(req, res){
    connection.query('CALL sp_account_balance_daily(' + "'" + req.user + "','" + wstmtDate + "'" + ',"EOQuarter")', function(err, resultsAccountBalanceDaily, fieldsAccountBalanceDaily) {
        if (err) {
            console.log(err);
        } else {
            connection.query('CALL sp_trade_history(' + "'" + req.user + "','" + wstmtDate + "'" + ',"EOQuarter","Asc")', function(err, resultsMonthlyTrades, fieldsMonthlyTrades) {
                if (err) {
                    console.log(err);
                } else {
                    connection.query('CALL sp_account_allocation_daily(' + "'" + req.user + "','" + wstmtDate + "'" + ')', function(err, resultsAccountAllocStart, fieldsAccountAllocStart) {
                        if (err) {
                            console.log(err);
                        } else {
                            connection.query('CALL sp_account_allocation_daily(' + "'" + req.user + "','" + resultsAccountBalanceDaily[0][resultsAccountBalanceDaily[0].length - 1].date + "'" + ')', function(err, resultsAccountAllocEnd, fieldsAccountAllocEnd) {
                                if (err) {
                                    console.log(err);
                                } else {
                                    connection.query('CALL sp_most_traded_currencies(' + "'" + req.user + "','" + wstmtDate + "'" + ',"EOQuarter")', function(err, resultsMostTradedCurrencies, fieldsMostTradedCurrencies) {
                                        if (err) {
                                            console.log(err);
                                        } else {
                                            connection.query('CALL sp_past_performance_statement_graph(' + "'" + wcurrency_code + "','" + wstmtDate + "'" + ',"EOQuarter")', function(err, resultsPastPerfStatementGraph, fieldsPastPerfStatementGraph) {
                                                if (err) {
                                                    console.log(err);
                                                } else {
        
                                                    var wdata = [];
                                                    var wcurs= [];
                                                    
                                                    wcurs.push(resultsMostTradedCurrencies[0]);
                                                    wcurs.push(resultsMostTradedCurrencies[1]);
                                                    wcurs.push(resultsMostTradedCurrencies[2]);
                                                    wcurs.push(resultsMostTradedCurrencies[3]);
                                        
                                                    wdata.push(resultsAccountBalanceDaily[0]);
                                                    wdata.push(resultsMonthlyTrades[0]);
                                                    wdata.push(resultsAccountAllocStart[0]);
                                                    wdata.push(resultsAccountAllocEnd[0]);
                                                    wdata.push(wcurs);
                                                    wdata.push(resultsPastPerfStatementGraph[0]);
                                        
                                        
                                                    res.render("quarterlyStatement.ejs", {currency_code: wcurrency_code, data: wdata, page: "quarterlyStatement"});
                                                }
                                            });
                                        }
                                    });
                                }
                            });
                        }
                    });
                }
            });
        }
    });
});

app.post("/quarterlyStatement", function(req, res){
    if(req.body.stmtDate){
        wstmtDate = req.body.stmtDate;
    }
    res.redirect("/quarterlyStatement");
});




app.get("/yearlyStatement", isLoggedIn, function(req, res){
    var wdata = wstmtDate; //This is just for testing here!!!
    res.render("yearlyStatement.ejs", {data: wdata, page: "yearlyStatement"});
});

app.post("/yearlyStatement", function(req, res){
    if(req.body.stmtDate){
        wstmtDate = req.body.stmtDate;
    }
    res.redirect("/yearlyStatement");
});








//login failure
app.get("/loginError", function(req, res){
    res.render("landing.ejs", {message: "Incorrect Password!"});
});



//login attempt
app.post("/login", passport.authenticate("local", 
    {
        successRedirect: "/trading",
        failureRedirect: "/loginError"
    }), function(req, res){
});


//sign up attempt
app.post("/register", function(req, res){
    if (req.body.password != req.body.confirmPassword) {
        return res.render("landing.ejs", {message: "The Passwords must match!"});
    } else if (req.body.username.indexOf(' ') >= 0 || req.body.password.indexOf(' ') >= 0){
        return res.render("landing.ejs", {message: "Username and Password can not contain spaces!"});
    } else if (req.body.baseCurrency == 'Choose...'){
        return res.render("landing.ejs", {message: "Please select a home currency!"});
    } else {
        bcrypt.hash(req.body.password, 10, function(err, hash){
            if (err) {
                console.log(err);
                return res.render("landing.ejs", {message: "Error siging up, please try again!"});  
            } else {
                connection.query('INSERT INTO user (username, password, base_currency_id) SELECT ?, ?, ( SELECT id FROM currency WHERE code = ? )', [req.body.username, hash, req.body.baseCurrency], function (error, results, fields) {
                    if (error){
                        console.log(error);
                        return res.render("landing.ejs", {message: "Username already exists!"});  
                    } else {
                        req.login(req.body.username, function(err){
                            if (err) {
                                console.log(err); 
                            } else {
                                connection.query('CALL sp_gift(' + "'" + req.user + "','" + 1000 + "'" + ')', function(err, results, fields) {
                                    if (err){
                                        console.log(err);
                                    } else {
                                        req.login(req.body.username, function(err){
                                            if (err) {
                                                console.log(err); 
                                            } else {
                                                res.redirect("/trading");                            
                                            }
                                        });
                                    }
                                });
                            }
                        });
                    }
                });
            }
        });
    }
});


//logout attempt
app.get("/logout", function(req, res){
    req.logout();
    //req.session.destroy();
    res.redirect("/");
});

















//catch all else
app.all("*", function(req, res){
    res.redirect("/");
});


//Loading exchange rates from API daily and hourly
//------------------------------------------------


setInterval(function() {
    var d = new Date();
    
    //Pull Daily rates
    if (d.getHours() == 0 && d.getMinutes() == 45 ) { 

        var dy = new Date();
        var linkdy = "http://data.fixer.io/api/" + dy.getFullYear() + '-' + ('0' + (dy.getMonth() + 1)).slice(-2) + '-' + ('0' + dy.getDate()).slice(-2) + "?access_key=" + process.env.FIXER_API_KEY + "&base=EUR&symbols=AUD,BRL,CAD,CHF,CNY,EUR,GBP,HKD,INR,JPY,KRW,MXN,NOK,NZD,RUB,SEK,SGD,TRY,USD,ZAR";

        axios.get(linkdy)
            .then(function(exchange_rates){
                if(exchange_rates.data.date) {
				    connection.query('CALL sp_insert_exchange_rates_daily(' + '1'  + ',' + exchange_rates.data.rates.AUD + ',' +
																			  '2'  + ',' + exchange_rates.data.rates.BRL + ',' +
																			  '3'  + ',' + exchange_rates.data.rates.CAD + ',' +
																			  '4'  + ',' + exchange_rates.data.rates.CHF + ',' +
																			  '5'  + ',' + exchange_rates.data.rates.CNY + ',' +
																			  '6'  + ',' + exchange_rates.data.rates.EUR + ',' +
																			  '7'  + ',' + exchange_rates.data.rates.GBP + ',' +
																			  '8'  + ',' + exchange_rates.data.rates.HKD + ',' +
																			  '9'  + ',' + exchange_rates.data.rates.INR + ',' +
																			  '10' + ',' + exchange_rates.data.rates.JPY + ',' +
																			  '11' + ',' + exchange_rates.data.rates.KRW + ',' +
																			  '12' + ',' + exchange_rates.data.rates.MXN + ',' +
																			  '13' + ',' + exchange_rates.data.rates.NOK + ',' +
																			  '14' + ',' + exchange_rates.data.rates.NZD + ',' +
																			  '15' + ',' + exchange_rates.data.rates.RUB + ',' +
																			  '16' + ',' + exchange_rates.data.rates.SEK + ',' +
																			  '17' + ',' + exchange_rates.data.rates.SGD + ',' +
																			  '18' + ',' + exchange_rates.data.rates.TRY + ',' +
																			  '19' + ',' + exchange_rates.data.rates.USD + ',' +
																			  '20' + ',' + exchange_rates.data.rates.ZAR + ',' +
																			dy.getFullYear() + ',' + dy.getMonth() + ',' + dy.getDate() +
																		')', 
						function (error, results, fields) {
							if (error) throw error;
                    });

                }
            });
    }


    //Pull Hourly rates
    if (d.getMinutes() == 50 ) { 
	
		var d2 = new Date();

		connection.query('CALL sp_insert_exchange_rates_hourly2(' + d2.getFullYear() + ',' + d2.getMonth() + ',' + d2.getDate() + ',' + d2.getHours() + ')', 
				function (error, results, fields) {
					if (error) throw error;
        });


	
    }

    //Fill any missing values
    if (d.getMinutes() == 55 ) { 
	
		connection.query('CALL sp_insert_exchange_rates_hourly_insert_missing_readings()', 
				function (error, results, fields) {
					if (error) throw error;
        });
	
    }

}, 60000); // every 1 minute = 60000


//Logging
setInterval(function() {
	//var dy = new Date(Date.now());
	//var dy = new Date();
    //connection.query('INSERT INTO log VALUES(' + "'" + dy.getHours().toString() + "'" + ')');
	//connection.query('INSERT INTO log VALUES(' + "'" + dy.getMinutes().toString() + "'" + ')');
	//connection.query('INSERT INTO log VALUES(' + "'" + dy.getMinutes().toString() + "'" + ')');
    //var dl = new Date(dy.getFullYear() + '-' + ('0' + (dy.getMonth() + 1)).slice(-2) + '-' + ('0' + dy.getDate()).slice(-2));
	//connection.query('INSERT INTO log VALUES(' + "'" + dl.getDate().toString() + "'" + ')');
	//dl.setDate(dl.getDate() - 1);
	//connection.query('INSERT INTO log VALUES(' + "'" + dl.getDate().toString() + "'" + ')');
	//var linkdy = "http://data.fixer.io/api/" + dl.getFullYear() + '-' + ('0' + (dl.getMonth() + 1)).slice(-2) + '-' + ('0' + dl.getDate()).slice(-2) + "access_key";
    //connection.query('INSERT INTO log VALUES(3)');
	//connection.query('INSERT INTO log VALUES(' + "'" + d.getMinutes().toString() + "'" + ')');
	//connection.query('INSERT INTO log VALUES(' + "'" + linkdy + "'" + ')');
	

}, 10000); // every 10 seconds



//Keep the app awake on Heroku
setInterval(function() {
    http.get("http://currencytide.com/");
}, 300000); // every 5 minutes (300000)



app.listen(process.env.PORT, process.env.IP, function(){
  console.log("The CurrencyTide Has Started!");
});

