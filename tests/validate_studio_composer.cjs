// Optional browser regression checks. Requires Playwright and a running Studio
// with an isolated history directory. Set STUDIO_URL to override the local URL.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
(async () => {
 const browser = await chromium.launch({headless:true, args:['--no-sandbox']});
 try {
 const page = await browser.newPage({viewport:{width:1440,height:1000}});
 page.setDefaultTimeout(20000);
 const errors=[]; page.on('pageerror', e=>errors.push(e.message));
 await page.goto(process.env.STUDIO_URL || 'http://127.0.0.1:8766');
 await page.waitForFunction(()=>document.querySelectorAll('.body-table tbody tr').length === 2 && !document.querySelector('#run').disabled);
 const cell=page.getByRole('textbox',{name:'Body 2, Mass (kg)',exact:true});
 const original=await cell.inputValue();
 await cell.fill('-1');
 await page.waitForFunction(()=>document.querySelector('#run').disabled && document.querySelector('#error_masses').textContent.includes('greater than zero'));
 await cell.fill(original);
 await page.waitForFunction(()=>!document.querySelector('#run').disabled);
 await page.locator('#duration').fill('-1');
 await page.waitForFunction(()=>document.querySelector('#run').disabled && document.querySelector('#error_duration').textContent.includes('positive'));
 await page.locator('#timestep').fill('1'); await page.locator('#duration').fill('10.5');
 await page.waitForFunction(()=>document.querySelector('#error_timestep').textContent.includes('integer'));
 await page.locator('#duration').fill('10');
 await page.waitForFunction(()=>!document.querySelector('#run').disabled && document.querySelector('#configuration_feedback').textContent.includes('10'));
 await page.locator('summary').click();
 await page.locator('#parameter_masses').fill('[2,3]');
 assert.equal(await cell.inputValue(),'3');
 await page.locator('#parameter_positions').fill('broken');
 await page.waitForFunction(()=>document.querySelector('#run').disabled && document.querySelector('#error_positions').textContent.includes('valid JSON'));
 await page.locator('#parameter_positions').fill('[[0,0],[1,0]]');
 await page.waitForFunction(()=>!document.querySelector('#run').disabled && document.querySelectorAll('.body-table tbody tr').length===2);
 await page.evaluate(()=>$('#system')[0].selectize.setValue('n_body'));
 await page.waitForSelector('.add-body');
 await page.waitForFunction(()=>!document.querySelector('#run').disabled);
 const count=await page.locator('.body-table tbody tr').count();
 await page.locator('.add-body').click();
 await page.waitForFunction(()=>document.querySelector('#run').disabled);
 const row=page.locator('.body-table tbody tr').last();
 const values=['1','123','456','0','0'];
 for(let i=0;i<5;i++) await row.locator('input').nth(i).fill(values[i]);
 await page.waitForFunction(()=>!document.querySelector('#run').disabled);
 assert.equal(await page.locator('.body-table tbody tr').count(),count+1);
 await row.locator('.remove-body').click();
 await page.waitForFunction(()=>!document.querySelector('#run').disabled);
 assert.equal(await page.locator('.body-table tbody tr').count(),count);
 await page.evaluate(()=>$('#system')[0].selectize.setValue('three_body'));
 await page.waitForFunction(()=>document.querySelectorAll('.body-table tbody tr').length===3 && !document.querySelector('#run').disabled);
 assert.equal(await page.locator('.add-body').count(),0);
 // Submitting uses table edits, and reuse restores those same inputs.
 await page.locator('#timestep').fill('1');
 await page.locator('#duration').fill('10');
 await page.getByRole('textbox',{name:'Body 1, vx (m/s)',exact:true}).fill('1.2345678901234567');
 await page.waitForFunction(()=>!document.querySelector('#run').disabled);
 await page.locator('#run').click();
 await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Completed batch: 1 completed'),{},{timeout:30000})
   .catch(async error => { throw new Error(error.message + '\nStudio status: ' + await page.locator('#status').innerText()); });
 await page.locator('.run-card').first().getByRole('button',{name:'Reuse',exact:true}).click();
 await page.waitForFunction(()=>document.querySelector('#status').textContent.includes('Loaded exact'));
 assert.equal(await page.getByRole('textbox',{name:'Body 1, vx (m/s)',exact:true}).inputValue(),'1.2345678901234567');
 assert.deepEqual(errors,[]);
 console.log('Composer browser checks passed: table/JSON synchronization, validation, add/remove, system switching.');
 } finally { await browser.close(); }
})().catch(e=>{console.error(e);process.exit(1);});
