/* The existing JSON textareas are the canonical Shiny inputs. */
(function () {
  "use strict";
  const fields = ["masses", "positions", "velocities"];
  const columns = ["Mass (kg)", "x (m)", "y (m)", "vx (m/s)", "vy (m/s)"];
  function inputs(editor) {
    return fields.map(name => editor.querySelector("#parameter_" + name));
  }
  function publish(editor) {
    const rows = Array.from(editor.querySelectorAll("tbody tr"));
    const values = rows.map(row => Array.from(row.querySelectorAll("input")).map(input => {
      const value = input.value.trim() === "" ? NaN : Number(input.value);
      input.setAttribute("aria-invalid", String(!Number.isFinite(value) ||
        (input.dataset.column === "0" && value <= 0)));
      return Number.isFinite(value) ? value : null;
    }));
    const data = [values.map(row => row[0]), values.map(row => row.slice(1, 3)),
      values.map(row => row.slice(3, 5))];
    editor.publishing = true;
    inputs(editor).forEach((input, i) => {
      input.value = JSON.stringify(data[i]);
      // Commit immediately: a Run click must not overtake a textarea's
      // debounced change and submit the previous body state.
      Shiny.setInputValue(input.id, input.value, {priority: "event"});
    });
    editor.publishing = false;
    const add = editor.querySelector(".add-body");
    if (add) add.disabled = rows.length >= 256;
    editor.querySelectorAll(".remove-body").forEach(button => { button.disabled = rows.length <= 2; });
  }
  function appendRow(editor, table, values) {
    const row = document.createElement("tr");
    const index = table.tBodies[0].rows.length;
    const heading = document.createElement("th");
    heading.scope = "row";
    heading.textContent = "Body " + (index + 1);
    row.appendChild(heading);
    values.forEach((value, column) => {
      const cell = document.createElement("td");
      const input = document.createElement("input");
      input.type = "text";
      input.inputMode = "decimal";
      input.className = "form-control";
      input.value = value == null ? "" : String(value);
      input.dataset.column = column;
      input.setAttribute("aria-label", "Body " + (index + 1) + ", " + columns[column]);
      input.addEventListener("input", () => publish(editor));
      cell.appendChild(input);
      row.appendChild(cell);
    });
    if (editor.dataset.system === "n_body") {
      const cell = document.createElement("td");
      const button = document.createElement("button");
      button.type = "button";
      button.className = "btn btn-default remove-body";
      button.textContent = "Remove";
      button.setAttribute("aria-label", "Remove body " + (index + 1));
      button.addEventListener("click", () => {
        row.remove();
        publish(editor);
        rebuild(editor);
      });
      cell.appendChild(button);
      row.appendChild(cell);
    }
    table.tBodies[0].appendChild(row);
  }
  function rebuild(editor) {
    if (editor.publishing) return;
    const target = editor.querySelector(".body-table");
    const add = editor.querySelector(".add-body");
    let data;
    try {
      data = inputs(editor).map(input => JSON.parse(input.value));
      const n = data[0].length;
      if (!Array.isArray(data[0]) || n < 2 || n > 256 ||
          !data[0].every(value => value === null || typeof value === "number") ||
          !data.slice(1).every(matrix => Array.isArray(matrix) && matrix.length === n &&
            matrix.every(row => Array.isArray(row) && row.length === 2 &&
              row.every(value => value === null || typeof value === "number")))) throw new Error();
    } catch (_) {
      target.textContent = "The table needs a mass and two position/velocity coordinates per body. Correct the advanced JSON below to restore the table.";
      editor.querySelector("details").open = true;
      if (add) add.disabled = true;
      return;
    }
    const table = document.createElement("table");
    const head = table.createTHead().insertRow();
    ["Body"].concat(columns, editor.dataset.system === "n_body" ? ["Actions"] : []).forEach(label => {
      const th = document.createElement("th");
      th.scope = "col";
      th.textContent = label;
      head.appendChild(th);
    });
    table.createTBody();
    data[0].forEach((mass, i) => appendRow(editor, table, [mass].concat(data[1][i], data[2][i])));
    target.replaceChildren(table);
    editor.querySelectorAll(".remove-body").forEach(button => { button.disabled = data[0].length <= 2; });
    if (add) add.disabled = data[0].length >= 256;
  }
  function initialize() {
    document.querySelectorAll(".body-editor").forEach(editor => {
      if (editor.initialized || inputs(editor).some(input => !input)) return;
      editor.initialized = true;
      inputs(editor).forEach(input => input.addEventListener("input", () => rebuild(editor)));
      const add = editor.querySelector(".add-body");
      if (add) add.addEventListener("click", () => {
        const table = editor.querySelector("table");
        if (!table || table.tBodies[0].rows.length >= 256) return;
        // Require explicit new-body values rather than inventing a physical setup.
        appendRow(editor, table, [null, null, null, null, null]);
        publish(editor);
        table.tBodies[0].lastChild.querySelector("input").focus();
      });
      rebuild(editor);
    });
  }
  $(document).on("shiny:bound", initialize);
  // Apply the same immediate submission semantics to scalar and advanced JSON
  // edits; otherwise Shiny's text-input debounce can lag behind the Run button.
  $(document).on("input", "#settings input.shiny-bound-input, #settings textarea.shiny-bound-input", function () {
    const binding = $(this).data("shiny-input-binding");
    if (!binding) return;
    const type = binding.getType(this);
    Shiny.setInputValue(this.id + (type ? ":" + type : ""), binding.getValue(this), {priority: "event"});
  });
  $(document).on("shiny:connected", function () {
    Shiny.addCustomMessageHandler("studioValidation", function (message) {
      const errors = message.fields == null ? [] :
        (Array.isArray(message.fields) ? message.fields : [message.fields]);
      document.querySelectorAll("#settings input, #settings textarea, #settings select").forEach(input => {
        if (!input.id) return;
        const name = input.id.replace(/^parameter_/, "");
        input.setAttribute("aria-invalid", String(errors.includes(name)));
        if (document.getElementById("error_" + name)) input.setAttribute("aria-describedby", "error_" + name);
      });
      document.querySelectorAll(".body-editor tbody input").forEach(input => {
        const column = Number(input.dataset.column);
        const field = column === 0 ? "masses" : column < 3 ? "positions" : "velocities";
        input.setAttribute("aria-invalid", String(errors.includes(field)));
        input.setAttribute("aria-describedby", "error_" + field);
      });
    });
  });
  $(initialize);
})();
